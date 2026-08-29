# Plan - Automatic Welcome Bonus & Deferred Referral Rewards

We will automate the welcome bonus for new users and ensure referral rewards for referrers are only unlocked after the referee completes their first task.

## User Review Required

> [!IMPORTANT]
> - New users will receive their welcome bonus **immediately** upon registration.
> - Referrers will only receive their referral bonus after the new user completes their **first task**.
> - The existing manual "Claim Bonus" button and its requirement for social handles will be bypassed by the automatic credit, but social handles remain required for task participation to prevent botting.

## Proposed Changes

### Database - Welcome Bonus & Referral Logic

#### [Migrations]
- **Update `handle_new_user`**: Modify the registration trigger to automatically credit the welcome bonus to the new user immediately.
- **Update Referral Trigger**: Remove the logic that awards pending referral points to the *referrer* on signup.
- **New Trigger on `task_submissions`**: Add a trigger that checks when a user's first task is `verified`. When this happens, credit the referral bonus to their referrer (if any).
- **Harden `is_profile_complete`**: Ensure it's used consistently or simplified if social handles are the only gate.
- **Update `claim_welcome_bonus` RPC**: Keep it for backward compatibility or as a fallback, but it won't be needed for the primary flow anymore.

### Frontend - Dashboard & UI

#### [src/routes/_authenticated.dashboard.tsx]
- Remove any remaining "Welcome Bonus" claim logic or banners, as the bonus will be credited automatically.
- (Optional) Show a "Welcome Bonus Credited" notification/toast on first login if not already done by the database.

## Technical Details

### SQL Logic (Conceptual)

1.  **Registration (`handle_new_user`)**:
    ```sql
    -- Award welcome bonus to referee immediately
    INSERT INTO public.points_transactions (user_id, amount, type, description, status)
    VALUES (new.id, 50, 'welcome_bonus', 'Signup welcome bonus', 'completed');
    ```

2.  **First Task Verification**:
    ```sql
    -- Trigger on task_submissions update to 'verified'
    IF NEW.status = 'verified' AND NOT EXISTS (
        SELECT 1 FROM public.task_submissions 
        WHERE user_id = NEW.user_id AND status = 'verified' AND id != NEW.id
    ) THEN
        -- Award bonus to referrer
        SELECT referred_by INTO v_referrer_id FROM public.profiles WHERE id = NEW.user_id;
        IF v_referrer_id IS NOT NULL THEN
            INSERT INTO public.points_transactions (...) VALUES (v_referrer_id, ...);
        END IF;
    END IF;
    ```

## Verification Plan

### Manual Verification
- Register a new user with a referral code.
- Check if the new user's balance is 50 points immediately.
- Verify the referrer has NO pending or completed points yet.
- Complete a task as the new user and verify it (admin may need to approve or use auto-verify task).
- Check if the referrer receives the points after the task is verified.

### Automated Verification (Playwright)
- Create a test script that signs up a user with a referral code.
- Assert points_balance is 50.
- Check referrer balance remains unchanged.
- Simulate task completion and verification.
- Assert referrer balance increases.
