create or replace function public.claim_daily_reward(_user_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_streak_record record;
    v_points_to_add integer := 20;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
begin
    -- 1. Check if user already claimed today
    select * into v_streak_record 
    from public.user_streaks 
    where user_id = _user_id;

    if v_streak_record.last_activity_at is not null then
        v_last_claim := v_streak_record.last_activity_at::date;
        if v_last_claim = v_now::date then
            return json_build_object('success', false, 'message', 'Already claimed today');
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
        returning * into v_streak_record;
    else
        insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        values (_user_id, 1, greatest(coalesce(v_streak_record.longest_streak, 0), 1), v_now)
        on conflict (user_id) do update 
        set 
            current_streak = 1,
            last_activity_at = v_now
        returning * into v_streak_record;
    end if;

    -- 3. Determine points (25 if streak >= 7, otherwise 20)
    if v_streak_record.current_streak >= 7 then
        v_points_to_add := 25;
    end if;

    -- 4. Record transaction
    insert into public.points_transactions (user_id, amount, type, description, created_at)
    values (_user_id, v_points_to_add, 'earn', 'Daily reward claiming', v_now);

    return json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_streak_record.current_streak
    );
end;
$$;

grant execute on function public.claim_daily_reward(uuid) to authenticated;