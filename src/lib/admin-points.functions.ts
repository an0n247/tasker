import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

export const adjustUserPoints = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((data) =>
    z
      .object({
        userId: z.string().uuid(),
        amount: z.number().int(),
        reason: z.string().min(1),
        actionType: z.enum(["credit", "debit"]),
      })
      .parse(data),
  )
  .handler(async ({ data, context }) => {
    // Call the RPC with the caller's own authenticated client. The database
    // function derives the admin identity from auth.uid() and rejects
    // non-admins, so no caller-supplied admin ID is ever trusted.
    const { error: rpcError } = await (context.supabase.rpc as any)(
      "handle_admin_points_adjustment",
      {
        p_target_user_id: data.userId,
        p_amount: data.amount,
        p_action_type: data.actionType,
        p_reason: data.reason,
      },
    );

    if (rpcError) {
      console.error("Admin adjustment RPC error:", rpcError);
      throw new Error(rpcError.message || "Failed to adjust points");
    }

    return { success: true };
  });
