# Plan: Adjust Referral Bonus Values

Adjust the referral reward system so the referrer receives 75 points and the referee (new user) receives 50 points.

## User Review Required

> [!IMPORTANT]
> I will be setting the Referrer bonus to 75 points and the Referee (new user) bonus to 50 points.

## Proposed Changes

### Database (Supabase)

#### Update Referral Reward Function
- Modify `public.reward_referrer_on_signup()` function.
- Change `v_referee_reward_points` from 75 to 50.
- Update the notification message for the referee to mention 50 points.

### Frontend (React)

#### Authentication Page
- `src/routes/auth.tsx`: Update the sign-up description to mention a 50-point welcome bonus instead of 75.

#### Referral Page
- `src/routes/_authenticated.refer.tsx`: Review and ensure text accurately reflects that the referrer gets 75 points while the referee gets 50 (if mentioned).

## Verification Plan

### Automated Tests
- I will run a check to ensure the `reward_referrer_on_signup` function is updated correctly in the database.

### Manual Verification
- Check the Auth page to confirm the welcome bonus text is updated to 50 points.
- Check the Refer page to confirm the referral reward for the user is still 75 points.
