UPDATE public.profiles p
SET points_balance = COALESCE((
    SELECT SUM(CASE WHEN t.type = 'earn' THEN t.amount ELSE -t.amount END)
    FROM public.points_transactions t
    WHERE t.user_id = p.id
), 0);