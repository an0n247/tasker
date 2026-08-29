-- Update claim_daily_reward with the new streak bonus schedule:
-- Day 1: 5 PTS
-- Day 2: 5 PTS
-- Day 3: 10 PTS
-- Day 4: 10 PTS
-- Day 5: 15 PTS
-- Day 6: 15 PTS
-- Day 7+: 20 PTS
-- If streak cuts, it restarts from Day 1 (5 PTS).

CREATE OR REPLACE FUNCTION public.claim_daily_reward(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_streak_record record;
    v_points_to_add integer := 5;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
    v_result_streak integer := 1;
begin
    -- SECURITY CHECK: Ensure the authenticated user is only claiming for themselves
    if auth.uid() <> _user_id then
        return json_build_object('success', false, 'message', 'Unauthorized: You can only claim rewards for your own account.');
    end if;

    -- Use explicit transaction lock to prevent concurrent race conditions
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

    -- 3. Determine points based on new streak schedule:
    -- Day 1: 5, Day 2: 5, Day 3: 10, Day 4: 10, Day 5: 15, Day 6: 15, Day 7+: 20
    if v_result_streak = 1 then
        v_points_to_add := 5;
    elsif v_result_streak = 2 then
        v_points_to_add := 5;
    elsif v_result_streak = 3 then
        v_points_to_add := 10;
    elsif v_result_streak = 4 then
        v_points_to_add := 10;
    elsif v_result_streak = 5 then
        v_points_to_add := 15;
    elsif v_result_streak = 6 then
        v_points_to_add := 15;
    else
        v_points_to_add := 20;
    end if;

    -- 4. Record points transaction
    insert into public.points_transactions (user_id, amount, type, description, status, created_at)
    values (_user_id, v_points_to_add, 'earn', format('Day %s Daily Check-in Streak Bonus', v_result_streak), 'completed', v_now);

    -- 5. Create instant in-app notification
    insert into public.notifications (user_id, title, message, type, created_at)
    values (_user_id, 'Daily Streak Bonus Claimed! 🔥', format('You claimed +%s PTS for maintaining your Day %s streak!', v_points_to_add, v_result_streak), 'points', v_now);

    return json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_result_streak,
        'message', format('Day %s streak bonus claimed! +%s points', v_result_streak, v_points_to_add)
    );
end;
$function$;
