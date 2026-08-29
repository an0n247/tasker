/**
 * End-to-end admin workflow tests.
 *
 * These run against the real backend. A throwaway admin user and a throwaway
 * member user are provisioned with the service role, then every admin action is
 * executed through a normal signed-in client (so RLS policies, GRANTs, check
 * constraints and audit triggers are all exercised exactly as in the app).
 *
 * Run with: bunx vitest run tests/admin-workflows.spec.ts
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { afterAll, beforeAll, describe, expect, test } from "vitest";

const SUPABASE_URL = process.env["SUPABASE_URL"] ?? process.env["VITE_SUPABASE_URL"]!;
const PUBLISHABLE_KEY =
  process.env["SUPABASE_PUBLISHABLE_KEY"] ?? process.env["VITE_SUPABASE_PUBLISHABLE_KEY"]!;
const SERVICE_ROLE_KEY = process.env["SUPABASE_SERVICE_ROLE_KEY"]!;

const suite = SUPABASE_URL && PUBLISHABLE_KEY && SERVICE_ROLE_KEY ? describe : describe.skip;

const stamp = Date.now();
const ADMIN_EMAIL = `e2e-admin-${stamp}@example.com`;
const MEMBER_EMAIL = `e2e-member-${stamp}@example.com`;
const PASSWORD = `E2e!${stamp}aA`;

/** Fails the test with the Postgres/PostgREST message so RLS + constraint errors are readable. */
function ok<T>(result: { data: T; error: { message: string } | null }, label: string): T {
  if (result.error) throw new Error(`${label}: ${result.error.message}`);
  return result.data;
}

suite("admin workflows (RLS + constraints)", () => {
  let admin: SupabaseClient;
  let asAdmin: SupabaseClient;
  let adminId: string;
  let memberId: string;
  let taskId: string;
  let rewardId: string;

  beforeAll(async () => {
    admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const createUser = async (email: string) => {
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: PASSWORD,
        email_confirm: true,
        user_metadata: { username: email.split("@")[0] },
      });
      if (error) throw new Error(`createUser ${email}: ${error.message}`);
      return data.user!.id;
    };

    adminId = await createUser(ADMIN_EMAIL);
    memberId = await createUser(MEMBER_EMAIL);

    ok(
      await admin.from("user_roles").insert({ user_id: adminId, role: "admin" }).select(),
      "grant admin role",
    );

    asAdmin = createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error } = await asAdmin.auth.signInWithPassword({
      email: ADMIN_EMAIL,
      password: PASSWORD,
    });
    if (error) throw new Error(`admin sign-in: ${error.message}`);
  }, 60_000);

  afterAll(async () => {
    if (taskId) await admin.from("tasks").delete().eq("id", taskId);
    if (rewardId) await admin.from("rewards").delete().eq("id", rewardId);
    for (const id of [adminId, memberId].filter(Boolean)) {
      await admin.auth.admin.deleteUser(id);
    }
  }, 60_000);

  test("admin session resolves the admin role", async () => {
    const isAdmin = ok(
      await asAdmin.rpc("has_role", { _user_id: adminId, _role: "admin" }),
      "has_role",
    );
    expect(isAdmin).toBe(true);
  });

  test("tasks: create, update, list and delete", async () => {
    const created = ok(
      await asAdmin
        .from("tasks")
        .insert({
          title: `E2E task ${stamp}`,
          description: "created by admin e2e test",
          points: 25,
          category: "Social",
          is_active: true,
        })
        .select()
        .single(),
      "insert task",
    );
    taskId = created.id;

    ok(
      await asAdmin.from("tasks").update({ points: 30, title: `E2E task ${stamp} v2` }).eq("id", taskId).select().single(),
      "update task",
    );

    const listed = ok(await asAdmin.from("tasks").select("id,title,points"), "select tasks");
    expect(listed.some((t: { id: string }) => t.id === taskId)).toBe(true);
  });

  test("rewards: create and update", async () => {
    const created = ok(
      await asAdmin
        .from("rewards")
        .insert({
          title: `E2E reward ${stamp}`,
          description: "created by admin e2e test",
          cost_points: 40,
          stock_count: 5,
          is_active: true,
          category: "Airtime",
        })
        .select()
        .single(),
      "insert reward",
    );
    rewardId = created.id;

    ok(
      await asAdmin.from("rewards").update({ stock_count: 4 }).eq("id", rewardId).select().single(),
      "update reward",
    );
  });

  test("points: credit and debit a member through the admin RPC", async () => {
    ok(
      await asAdmin.rpc("handle_admin_points_adjustment", {
        p_target_user_id: memberId,
        p_amount: 100,
        p_action_type: "credit",
        p_reason: "e2e credit",
      }),
      "credit points",
    );
    ok(
      await asAdmin.rpc("handle_admin_points_adjustment", {
        p_target_user_id: memberId,
        p_amount: 25,
        p_action_type: "debit",
        p_reason: "e2e debit",
      }),
      "debit points",
    );

    const profile = ok(
      await admin.from("profiles").select("points_balance").eq("id", memberId).single(),
      "read member balance",
    );
    const txns = ok(
      await admin
        .from("points_transactions")
        .select("amount")
        .eq("user_id", memberId)
        .eq("status", "completed"),
      "read member transactions",
    );
    const sum = txns.reduce((acc: number, t: { amount: number }) => acc + t.amount, 0);
    expect(profile.points_balance).toBe(sum);
  });

  test("task submissions: verify a pending submission", async () => {
    const submission = ok(
      await admin
        .from("task_submissions")
        .insert({ user_id: memberId, task_id: taskId, status: "pending" })
        .select()
        .single(),
      "seed submission",
    );

    ok(
      await asAdmin.rpc("verify_task_submission", {
        _submission_id: submission.id,
        _approve: true,
        _admin_note: "e2e approval",
      }),
      "verify submission",
    );

    const updated = ok(
      await admin.from("task_submissions").select("status").eq("id", submission.id).single(),
      "read submission",
    );
    expect(updated.status).toBe("verified");
  });

  test("redemptions: approve then reject with refund", async () => {
    const redemption = ok(
      await admin
        .from("redemptions")
        .insert({ user_id: memberId, reward_id: rewardId, status: "pending" })
        .select()
        .single(),
      "seed redemption",
    );

    const approved: { success: boolean; message?: string } = ok(
      await asAdmin.rpc("process_redemption_status_change", {
        _redemption_id: redemption.id,
        _new_status: "approved",
        _rejection_reason: "",
      }),
      "approve redemption",
    );
    expect(approved.success, approved.message).toBe(true);

    const rejected: { success: boolean; message?: string } = ok(
      await asAdmin.rpc("process_redemption_status_change", {
        _redemption_id: redemption.id,
        _new_status: "rejected",
        _rejection_reason: "e2e rejection",
      }),
      "reject redemption",
    );
    expect(rejected.success, rejected.message).toBe(true);

    await admin.from("redemptions").delete().eq("id", redemption.id);
  });

  test("notifications: admin can send a user notification", async () => {
    const result: { success: boolean } = ok(
      await asAdmin.rpc("send_user_notification", {
        _user_id: memberId,
        _title: "E2E notification",
        _message: "sent by admin e2e test",
        _type: "system",
      }),
      "send notification",
    );
    expect(result.success).toBe(true);
  });

  test("analytics RPCs run for admins", async () => {
    const from = new Date(Date.now() - 7 * 864e5).toISOString();
    const to = new Date().toISOString();
    ok(
      await asAdmin.rpc("get_daily_task_completions", {
        start_date: from,
        end_date: to,
        granularity: "day",
        filter_task_id: null,
      }),
      "daily completions",
    );
    ok(
      await asAdmin.rpc("get_repeatable_task_stats", {
        start_date: from,
        end_date: to,
        filter_task_id: null,
      }),
      "repeatable stats",
    );
  });

  test("admin can read users, audit logs and settings", async () => {
    ok(await asAdmin.from("profiles").select("id,email,points_balance").limit(5), "read profiles");
    ok(await asAdmin.from("admin_audit_logs").select("id,action_type").limit(5), "read audit logs");
    ok(await asAdmin.from("app_settings").select("key,value").limit(5), "read settings");
    ok(await asAdmin.from("role_permissions").select("role,tab_name,is_enabled"), "read role permissions");
    ok(await asAdmin.from("fraud_flags").select("id,type").limit(5), "read fraud flags");
  });

  test("app settings can be updated by an admin", async () => {
    const current = ok(
      await asAdmin.from("app_settings").select("id,key,value").eq("key", "daily_task_limit").maybeSingle(),
      "read daily_task_limit",
    );
    if (!current) return;
    ok(
      await asAdmin.from("app_settings").update({ value: current.value }).eq("id", current.id).select().single(),
      "update daily_task_limit",
    );
  });

  test("role assignment writes are admin-only", async () => {
    // The app performs this through a server function using the service role after
    // verifying the caller; direct client writes must stay blocked by RLS.
    const { error } = await asAdmin.from("user_roles").insert({ user_id: memberId, role: "moderator" });
    expect(error).not.toBeNull();
  });

  test("deleting a task is allowed for admins", async () => {
    const { error } = await asAdmin.from("tasks").delete().eq("id", taskId);
    expect(error).toBeNull();
    taskId = "";
  });
});
