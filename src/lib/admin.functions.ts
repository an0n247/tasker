import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

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
    // Verified with the caller's own JWT-scoped client before any privileged write.
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
