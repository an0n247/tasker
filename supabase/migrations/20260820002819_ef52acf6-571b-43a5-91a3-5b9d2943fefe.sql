
-- Profiles: Allow admins to select all
CREATE POLICY "Admins can select all profiles" ON public.profiles
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Referrals: Allow admins to select all
CREATE POLICY "Admins can select all referrals" ON public.referrals
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Points Transactions: Allow admins to select all
CREATE POLICY "Admins can select all transactions" ON public.points_transactions
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Analytics Events: Allow admins to select all
CREATE POLICY "Admins can select all analytics events" ON public.analytics_events
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- User Streaks: Allow admins to select all
CREATE POLICY "Admins can select all streaks" ON public.user_streaks
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));
