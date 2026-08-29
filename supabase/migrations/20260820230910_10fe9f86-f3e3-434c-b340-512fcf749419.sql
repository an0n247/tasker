
-- Add transaction_id column to notifications
ALTER TABLE public.notifications 
ADD COLUMN transaction_id UUID REFERENCES public.points_transactions(id) ON DELETE SET NULL;

-- Grant access (good practice even if already granted to the table)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

-- Update the notification trigger function to include transaction_id
CREATE OR REPLACE FUNCTION public.notify_on_points_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type, transaction_id)
    VALUES (
        NEW.user_id,
        CASE WHEN NEW.amount > 0 THEN 'Points Earned!' ELSE 'Points Spent' END,
        NEW.description,
        'points',
        NEW.id
    );
    RETURN NEW;
END;
$function$;

-- Update referer reward trigger as well to handle the transaction_id if we want consistency
-- However, the notify_on_points_transaction trigger will ALREADY fire when 
-- reward_referrer_on_signup inserts into points_transactions.
-- Let's double check if notify_on_points_transaction is enabled on points_transactions.
-- It is: map[table_name:points_transactions trigger_name:on_points_transaction]
