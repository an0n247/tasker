# Plan: Automated Points Sync and Dashboard Real-time Totals

The user reported that completed tasks are not correctly updating the total points on the dashboard. Investigation revealed that the `profiles.points_balance` column is not automatically synchronized with the `points_transactions` table. I will implement a database trigger to ensure the balance is always accurate and synchronized across all point-earning and redemption activities.

## User Review Required

> [!IMPORTANT]
> I will be applying a database migration that adds a trigger to the `points_transactions` table. This will automatically update your point balance whenever points are earned (tasks, daily rewards, referrals) or redeemed. I will also perform a one-time synchronization to ensure your current balance reflects all past activities.

## Proposed Changes

### Database Migration
- **Create `update_user_points_balance()` function**: A `SECURITY DEFINER` function that calculates the new balance whenever a row is inserted, updated, or deleted in the `points_transactions` table.
- **Add Trigger**: Attach the function to the `points_transactions` table.
- **One-time Sync**: Update all existing profile balances by summing their transaction history.
- **Security**: Revoke public execution rights for the balance update function.

### Frontend Enhancements
- **Refetching**: Ensure the dashboard and navigation point displays refetch when tasks are submitted or daily rewards are claimed.

## Technical Details

### SQL Migration
```sql
CREATE OR REPLACE FUNCTION public.update_user_points_balance()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.profiles
        SET points_balance = points_balance + NEW.amount
        WHERE id = NEW.user_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.profiles
        SET points_balance = points_balance - OLD.amount
        WHERE id = OLD.user_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE public.profiles
        SET points_balance = points_balance - OLD.amount + NEW.amount
        WHERE id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER on_points_transaction_change
AFTER INSERT OR UPDATE OR DELETE ON public.points_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_user_points_balance();

-- Initial sync
UPDATE public.profiles p
SET points_balance = COALESCE((
    SELECT SUM(amount)
    FROM public.points_transactions
    WHERE user_id = p.id
), 0);
```

### Affected Files
- `supabase--migration`: New migration for balance triggers.
- `src/routes/_authenticated.earn.tsx`: Update `submit_task` logic to invalidate the `profile` query on success.
