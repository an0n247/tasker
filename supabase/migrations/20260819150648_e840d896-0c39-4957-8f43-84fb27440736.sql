-- 1. Restrict claim_daily_reward
REVOKE ALL ON FUNCTION public.claim_daily_reward(uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;

-- 2. Update claim_daily_reward to verify the caller matches the user_id argument
CREATE OR REPLACE FUNCTION public.claim_daily_reward(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_streak_record record;
    v_points_to_add integer := 20;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
    v_result_streak integer;
begin
    -- SECURITY CHECK: Ensure the authenticated user is only claiming for themselves
    if auth.uid() <> _user_id then
        return json_build_object('success', false, 'message', 'Unauthorized: You can only claim rewards for your own account.');
    end if;

    -- Use a explicit lock to prevent concurrent claims for the same user
    perform pg_advisory_xact_lock(hashtext(_user_id::text));

    -- 1. Check if user already claimed today
    select * into v_streak_record 
    from public.user_streaks 
    where user_id = _user_id;

    if v_streak_record.last_activity_at is not null then
        v_last_claim := v_streak_record.last_activity_at::date;
        if v_last_claim = v_now::date then
            return json_build_object('success', false, 'message', 'You have already claimed your reward for today.');
        end if;
        
        -- Check if it is consecutive (yesterday)
        if v_last_claim = (v_now::date - interval '1 day')::date then
            v_is_consecutive := true;
        end if;
    end if;

    -- 2. Update streak
    if v_is_consecutive then
        update public.user_streaks
        set 
            current_streak = current_streak + 1,
            longest_streak = greatest(longest_streak, current_streak + 1),
            last_activity_at = v_now
        where user_id = _user_id
        returning current_streak into v_result_streak;
    else
        insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        values (_user_id, 1, 1, v_now)
        on conflict (user_id) do update 
        set 
            current_streak = 1,
            last_activity_at = v_now
        returning current_streak into v_result_streak;
    end if;

    -- 3. Determine points (25 if streak >= 7, otherwise 20)
    if v_result_streak >= 7 then
        v_points_to_add := 25;
    end if;

    -- 4. Record transaction
    insert into public.points_transactions (user_id, amount, type, description, created_at)
    values (_user_id, v_points_to_add, 'earn', 'Daily reward claiming', v_now);

    return json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_result_streak,
        'message', 'Reward claimed successfully!'
    );
end;
$function$;