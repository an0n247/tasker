import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

export const getAdminUsersList = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .validator((data: { search?: string; page?: number; limit?: number }) => data)
  .handler(async ({ data, context }) => {
    const { supabase, userId } = context;

    // Check admin authorization
    const { data: isAdmin } = await (supabase.rpc as any)("has_role", {
      _user_id: userId,
      _role: "admin",
    });

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const client = isAdmin ? supabaseAdmin : supabase;

    const page = Math.max(1, Number(data.page) || 1);
    const limit = Math.max(1, Math.min(100, Number(data.limit) || 10));
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    let query = client.from("profiles").select("*", { count: "exact" });
    if (data.search && data.search.trim()) {
      const s = data.search.trim();
      query = query.or(`username.ilike.%${s}%,email.ilike.%${s}%,full_name.ilike.%${s}%`);
    }

    const { data: profiles, count, error: profilesError } = await query
      .order("created_at", { ascending: false })
      .range(from, to);

    if (profilesError) {
      console.error("Error fetching admin profiles:", profilesError);
      throw profilesError;
    }

    const profileList = profiles || [];
    let roles: any[] = [];
    if (profileList.length > 0) {
      const userIds = profileList.map((p) => p.id);
      const { data: rolesData } = await client
        .from("user_roles")
        .select("user_id, role")
        .in("user_id", userIds);
      roles = rolesData || [];
    }

    const mappedUsers = profileList.map((profile) => ({
      ...profile,
      isAdmin: roles.some((r) => r.user_id === profile.id && r.role === "admin"),
      isModerator: roles.some((r) => r.user_id === profile.id && r.role === "moderator"),
      isTaskManager: roles.some((r) => r.user_id === profile.id && r.role === "task_manager"),
      currentRole: roles.find((r) => r.user_id === profile.id)?.role || "user",
    }));

    return { users: mappedUsers, totalCount: count || 0 };
  });

export const assignUserRole = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((data) =>
    z
      .object({
        userId: z.string().uuid(),
        role: z.enum(["admin", "moderator", "user", "task_manager", "tasker"]),
      })
      .parse(data),
  )
  .handler(async ({ data, context }) => {
    const { supabase, userId } = context;

    // Server-side authorization: the caller must be an authenticated admin.
    const { data: isAdmin, error: roleError } = await (supabase.rpc as any)("has_role", {
      _user_id: userId,
      _role: "admin",
    });

    if (roleError || !isAdmin) {
      throw new Error("Unauthorized: admin role required");
    }

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

    // The application treats roles as mutually exclusive. Remove stale roles
    // first so useAuth never receives multiple rows for one user.
    const { error: deleteError } = await supabaseAdmin
      .from("user_roles")
      .delete()
      .eq("user_id", data.userId);

    if (deleteError) throw new Error(deleteError.message);
    if (data.role === "user") return { success: true };

    const { error: insertError } = await supabaseAdmin.from("user_roles").insert({
      user_id: data.userId,
      role: data.role,
    });

    if (insertError) throw new Error(insertError.message);

    return { success: true };
  });
