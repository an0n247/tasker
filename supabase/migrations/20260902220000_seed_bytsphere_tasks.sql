-- ==============================================================================
-- Migration: Add 41 BytSphere Blog Tasks (Read, Like, Comment + Keyword Verification)
-- Points: 50 per task
-- ==============================================================================


-- Task 1: iOS 27: Your Complete Guide to Apple''s Latest Update
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: iOS 27: Your Complete Guide to Apple''s Latest Update',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/08/ios-27-your-complete-guide-to-apples.html',
    false,
    true,
    false,
    '{"keyword":"IOS27YOUR","hint":"Read \"iOS 27: Your Complete Guide to Apple''s Latest...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/08/ios-27-your-complete-guide-to-apples.html'
);

-- Task 2: Passkeys Explained: Why They''re Replacing Passwords
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Passkeys Explained: Why They''re Replacing Passwords',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/passkeys-explained-why-theyre-replacing.html',
    false,
    true,
    false,
    '{"keyword":"PASSKEYSEXPLAINEDWHY","hint":"Read \"Passkeys Explained: Why They''re Replacing Pas...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/passkeys-explained-why-theyre-replacing.html'
);

-- Task 3: Personal AI Assistants Are Here: How to Use Yours Today
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Personal AI Assistants Are Here: How to Use Yours Today',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/personal-ai-assistants-are-here-how-to.html',
    false,
    true,
    false,
    '{"keyword":"PERSONALAIASSISTANTS","hint":"Read \"Personal AI Assistants Are Here: How to Use Y...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/personal-ai-assistants-are-here-how-to.html'
);

-- Task 4: 10 AI Features Already on Your Phone You''re Not Using
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: 10 AI Features Already on Your Phone You''re Not Using',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/10-ai-features-already-on-your-phone.html',
    false,
    true,
    false,
    '{"keyword":"10AIFEATURES","hint":"Read \"10 AI Features Already on Your Phone You''re N...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/10-ai-features-already-on-your-phone.html'
);

-- Task 5: How to Fix a Phone Stuck on Bootloop (No Data Loss)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How to Fix a Phone Stuck on Bootloop (No Data Loss)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/how-to-fix-phone-stuck-on-bootloop-no.html',
    false,
    false,
    false,
    '{"keyword":"HOWTOFIX","hint":"Read \"How to Fix a Phone Stuck on Bootloop (No Data...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/how-to-fix-phone-stuck-on-bootloop-no.html'
);

-- Task 6: Tizeti Ad-Supported Internet: Worth It in 2026?
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Tizeti Ad-Supported Internet: Worth It in 2026?',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/tizeti-ad-supported-internet-worth-it.html',
    false,
    false,
    false,
    '{"keyword":"TIZETIADSUPPORTED","hint":"Read \"Tizeti Ad-Supported Internet: Worth It in 202...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/tizeti-ad-supported-internet-worth-it.html'
);

-- Task 7: How to Transfer Data from Old Android to New Phone
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How to Transfer Data from Old Android to New Phone',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/how-to-transfer-data-from-old-android.html',
    false,
    false,
    false,
    '{"keyword":"HOWTOTRANSFER","hint":"Read \"How to Transfer Data from Old Android to New ...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/how-to-transfer-data-from-old-android.html'
);

-- Task 8: How to Save Data on MTN, Airtel, Glo & 9mobile (2026)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How to Save Data on MTN, Airtel, Glo & 9mobile (2026)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/how-to-save-data-on-mtn-airtel-glo.html',
    false,
    false,
    false,
    '{"keyword":"HOWTOSAVE","hint":"Read \"How to Save Data on MTN, Airtel, Glo & 9mobil...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/how-to-save-data-on-mtn-airtel-glo.html'
);

-- Task 9: Buy Now, Pay Later: Get a Phone on Installment in Nigeria
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Buy Now, Pay Later: Get a Phone on Installment in Nigeria',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/buy-now-pay-later-get-phone-on.html',
    false,
    false,
    false,
    '{"keyword":"BUYNOWPAY","hint":"Read \"Buy Now, Pay Later: Get a Phone on Installmen...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/buy-now-pay-later-get-phone-on.html'
);

-- Task 10: Starlink in Nigeria 2026: Is It Worth Switching From MTN/Airtel?
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Starlink in Nigeria 2026: Is It Worth Switching From MTN/Airtel?',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/starlink-in-nigeria-2026-is-it-worth.html',
    false,
    false,
    false,
    '{"keyword":"STARLINKINNIGERIA","hint":"Read \"Starlink in Nigeria 2026: Is It Worth Switchi...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/starlink-in-nigeria-2026-is-it-worth.html'
);

-- Task 11: SIM Swap Fraud in Nigeria: How It Works & How to Protect Yourself
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: SIM Swap Fraud in Nigeria: How It Works & How to Protect Yourself',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/sim-swap-fraud-in-nigeria-how-it-works.html',
    false,
    false,
    false,
    '{"keyword":"SIMSWAPFRAUD","hint":"Read \"SIM Swap Fraud in Nigeria: How It Works & How...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/sim-swap-fraud-in-nigeria-how-it-works.html'
);

-- Task 12: Why Does Your Phone Overheat? Real Causes & Fixes (2026)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Why Does Your Phone Overheat? Real Causes & Fixes (2026)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/why-does-your-phone-overheat-real.html',
    false,
    false,
    false,
    '{"keyword":"WHYDOESYOUR","hint":"Read \"Why Does Your Phone Overheat? Real Causes & F...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/why-does-your-phone-overheat-real.html'
);

-- Task 13: Is Free Public Wi-Fi Safe? 7 Things Every Nigerian Should Know
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Is Free Public Wi-Fi Safe? 7 Things Every Nigerian Should Know',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/is-free-public-wi-fi-safe-7-things.html',
    false,
    false,
    false,
    '{"keyword":"ISFREEPUBLIC","hint":"Read \"Is Free Public Wi-Fi Safe? 7 Things Every Nig...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/is-free-public-wi-fi-safe-7-things.html'
);

-- Task 14: WhatsApp Usernames: Everything Nigerians Need to Know in 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: WhatsApp Usernames: Everything Nigerians Need to Know in 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/07/whatsapp-usernames-everything-nigerians.html',
    false,
    false,
    false,
    '{"keyword":"WHATSAPPUSERNAMESEVERYTHING","hint":"Read \"WhatsApp Usernames: Everything Nigerians Need...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/07/whatsapp-usernames-everything-nigerians.html'
);

-- Task 15: Best Budget Smartphones Under ₦200,000 in Nigeria (2026)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Best Budget Smartphones Under ₦200,000 in Nigeria (2026)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/best-budget-smartphones-under-200000-in.html',
    false,
    false,
    false,
    '{"keyword":"BESTBUDGETSMARTPHONES","hint":"Read \"Best Budget Smartphones Under ₦200,000 in Nig...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/best-budget-smartphones-under-200000-in.html'
);

-- Task 16: How to Free Up Storage on Android Without Deleting Important Files
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How to Free Up Storage on Android Without Deleting Important Files',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/how-to-free-up-storage-on-android.html',
    false,
    false,
    false,
    '{"keyword":"HOWTOFREE","hint":"Read \"How to Free Up Storage on Android Without Del...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/how-to-free-up-storage-on-android.html'
);

-- Task 17: 5G in Nigeria 2026: What It Means for Your Phone & Data
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: 5G in Nigeria 2026: What It Means for Your Phone & Data',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/5g-in-nigeria-2026-what-it-means-for.html',
    false,
    false,
    false,
    '{"keyword":"5GINNIGERIA","hint":"Read \"5G in Nigeria 2026: What It Means for Your Ph...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/5g-in-nigeria-2026-what-it-means-for.html'
);

-- Task 18: How AI Is Already Changing Everyday Life in Nigeria in 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How AI Is Already Changing Everyday Life in Nigeria in 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/how-ai-is-already-changing-everyday.html',
    false,
    false,
    false,
    '{"keyword":"HOWAIIS","hint":"Read \"How AI Is Already Changing Everyday Life in N...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/how-ai-is-already-changing-everyday.html'
);

-- Task 19: Infinix Note 60 Pro Review: Is It the Best Mid-Range Phone in Nigeria?
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Infinix Note 60 Pro Review: Is It the Best Mid-Range Phone in Nigeria?',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/infinix-note-60-pro-review-is-it-best.html',
    false,
    false,
    false,
    '{"keyword":"INFINIXNOTE60","hint":"Read \"Infinix Note 60 Pro Review: Is It the Best Mi...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/infinix-note-60-pro-review-is-it-best.html'
);

-- Task 20: iPhone vs Tecno: Which Should a Nigerian Buy in 2026?
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: iPhone vs Tecno: Which Should a Nigerian Buy in 2026?',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/iphone-vs-tecno-which-should-nigerian.html',
    false,
    false,
    false,
    '{"keyword":"IPHONEVSTECNO","hint":"Read \"iPhone vs Tecno: Which Should a Nigerian Buy ...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/iphone-vs-tecno-which-should-nigerian.html'
);

-- Task 21: 10 Android Tips Every Android User Should Know in 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: 10 Android Tips Every Android User Should Know in 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/10-android-tips-every-tecno-infinix.html',
    false,
    false,
    false,
    '{"keyword":"10ANDROIDTIPS","hint":"Read \"10 Android Tips Every Android User Should Kno...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/10-android-tips-every-tecno-infinix.html'
);

-- Task 22: Should You Charge Your Phone to 80%? Battery Guide 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Should You Charge Your Phone to 80%? Battery Guide 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/should-you-charge-your-phone-to-80.html',
    false,
    false,
    false,
    '{"keyword":"SHOULDYOUCHARGE","hint":"Read \"Should You Charge Your Phone to 80%? Battery ...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/should-you-charge-your-phone-to-80.html'
);

-- Task 23: Why Your Phone Becomes Slow Over Time (And How to Fix It)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Why Your Phone Becomes Slow Over Time (And How to Fix It)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/06/why-your-phone-becomes-slow-over-time.html',
    false,
    false,
    false,
    '{"keyword":"WHYYOURPHONE","hint":"Read \"Why Your Phone Becomes Slow Over Time (And Ho...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/06/why-your-phone-becomes-slow-over-time.html'
);

-- Task 24: Hidden iPhone Features You Should Start Using in 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Hidden iPhone Features You Should Start Using in 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/05/hidden-iphone-features-you-should-start.html',
    false,
    false,
    false,
    '{"keyword":"HIDDENIPHONEFEATURES","hint":"Read \"Hidden iPhone Features You Should Start Using...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/05/hidden-iphone-features-you-should-start.html'
);

-- Task 25: Hidden ChatGPT Features Most People Don’t Know in 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Hidden ChatGPT Features Most People Don’t Know in 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/05/hidden-chatgpt-features-most-people.html',
    false,
    false,
    false,
    '{"keyword":"HIDDENCHATGPTFEATURES","hint":"Read \"Hidden ChatGPT Features Most People Don’t Kno...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/05/hidden-chatgpt-features-most-people.html'
);

-- Task 26: 15 Powerful Websites That you Need to Know
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: 15 Powerful Websites That you Need to Know',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/05/15-internet-game-changers-websites-that.html',
    false,
    false,
    false,
    '{"keyword":"15INTERNETGAME","hint":"Read \"15 Powerful Websites That you Need to Know...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/05/15-internet-game-changers-websites-that.html'
);

-- Task 27: What Is eSIM? A Complete Beginner''s Guide
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: What Is eSIM? A Complete Beginner''s Guide',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/05/what-is-esim-and-how-does-it-work.html',
    false,
    false,
    false,
    '{"keyword":"WHATISESIM","hint":"Read \"What Is eSIM? A Complete Beginner''s Guide...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/05/what-is-esim-and-how-does-it-work.html'
);

-- Task 28: ChatGPT vs Gemini vs Claude: Best AI for Daily Use in 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: ChatGPT vs Gemini vs Claude: Best AI for Daily Use in 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/05/chatgpt-vs-gemini-vs-claude-which-ai-is.html',
    false,
    false,
    false,
    '{"keyword":"CHATGPTVSGEMINI","hint":"Read \"ChatGPT vs Gemini vs Claude: Best AI for Dail...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/05/chatgpt-vs-gemini-vs-claude-which-ai-is.html'
);

-- Task 29: Best Tech Skills to Learn in 2026 (Even Without a Tech Degree)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Best Tech Skills to Learn in 2026 (Even Without a Tech Degree)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/05/best-tech-skills-to-learn-in-2026-even.html',
    false,
    false,
    false,
    '{"keyword":"BESTTECHSKILLS","hint":"Read \"Best Tech Skills to Learn in 2026 (Even Witho...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/05/best-tech-skills-to-learn-in-2026-even.html'
);

-- Task 30: Save TikTok Videos Without Watermark on iPhone (2026)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Save TikTok Videos Without Watermark on iPhone (2026)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/04/iphone-hack-how-to-save-tiktok-videos.html',
    false,
    false,
    false,
    '{"keyword":"IPHONEHACKHOW","hint":"Read \"Save TikTok Videos Without Watermark on iPhon...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/04/iphone-hack-how-to-save-tiktok-videos.html'
);

-- Task 31: MTN & Airtel Suspend Airtime Borrowing in Nigeria (2026)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: MTN & Airtel Suspend Airtime Borrowing in Nigeria (2026)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/04/mtn-and-airtel-suspend-airtime.html',
    false,
    false,
    false,
    '{"keyword":"MTNANDAIRTEL","hint":"Read \"MTN & Airtel Suspend Airtime Borrowing in Nig...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/04/mtn-and-airtel-suspend-airtime.html'
);

-- Task 32: Beyond the Smart Bulb: 5 Emerging Trends Redefining the "Smart Home" by 2027
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Beyond the Smart Bulb: 5 Emerging Trends Redefining the "Smart Home" by 2027',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/04/beyond-smart-bulb-5-emerging-trends.html',
    false,
    false,
    false,
    '{"keyword":"BEYONDSMARTBULB","hint":"Read \"Beyond the Smart Bulb: 5 Emerging Trends Rede...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/04/beyond-smart-bulb-5-emerging-trends.html'
);

-- Task 33: How to Optimize Your Home Network for 8K Streaming and Low-Latency Gaming (2026 Guide)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How to Optimize Your Home Network for 8K Streaming and Low-Latency Gaming (2026 Guide)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/04/how-to-optimize-your-home-network-for.html',
    false,
    false,
    false,
    '{"keyword":"HOWTOOPTIMIZE","hint":"Read \"How to Optimize Your Home Network for 8K Stre...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/04/how-to-optimize-your-home-network-for.html'
);

-- Task 34: Is AI-Integrated Hardware Actually Worth It? The Truth About AI PCs and Phones in 2026
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Is AI-Integrated Hardware Actually Worth It? The Truth About AI PCs and Phones in 2026',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/04/is-ai-integrated-hardware-actually.html',
    false,
    false,
    false,
    '{"keyword":"ISAIINTEGRATED","hint":"Read \"Is AI-Integrated Hardware Actually Worth It? ...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/04/is-ai-integrated-hardware-actually.html'
);

-- Task 35: 10 Hidden Android Features You’re Probably Not Using (But Should!)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: 10 Hidden Android Features You’re Probably Not Using (But Should!)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/04/10-hidden-android-features-youre.html',
    false,
    false,
    false,
    '{"keyword":"10HIDDENANDROID","hint":"Read \"10 Hidden Android Features You’re Probably No...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/04/10-hidden-android-features-youre.html'
);

-- Task 36: Everything You Need to Know About Apple Music Subscription
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Everything You Need to Know About Apple Music Subscription',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/03/accessing-apple-music-premium-for-700.html',
    false,
    false,
    false,
    '{"keyword":"ACCESSINGAPPLEMUSIC","hint":"Read \"Everything You Need to Know About Apple Music...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/03/accessing-apple-music-premium-for-700.html'
);

-- Task 37: CapCut Pro Price in Nigeria: Is It Worth Paying For? (Updated 2026)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: CapCut Pro Price in Nigeria: Is It Worth Paying For? (Updated 2026)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/03/level-up-your-edits-get-capcut-pro-for.html',
    false,
    false,
    false,
    '{"keyword":"LEVELUPYOUR","hint":"Read \"CapCut Pro Price in Nigeria: Is It Worth Payi...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/03/level-up-your-edits-get-capcut-pro-for.html'
);

-- Task 38: Everything You Need to Know About Canva Pro (2026)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Everything You Need to Know About Canva Pro (2026)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2026/03/get-canva-pro-for-just-800-unlock-your.html',
    false,
    false,
    false,
    '{"keyword":"GETCANVAPRO","hint":"Read \"Everything You Need to Know About Canva Pro (...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2026/03/get-canva-pro-for-just-800-unlock-your.html'
);

-- Task 39: How to Get Meta Verified on Facebook (2026 Guide)
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How to Get Meta Verified on Facebook (2026 Guide)',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2025/07/get-facebook-verification-for-just-1.html',
    false,
    false,
    false,
    '{"keyword":"GETFACEBOOKVERIFICATION","hint":"Read \"How to Get Meta Verified on Facebook (2026 Gu...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2025/07/get-facebook-verification-for-just-1.html'
);

-- Task 40: Use the iPhone or iPad Touch as a computer mouse and keyboard.
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: Use the iPhone or iPad Touch as a computer mouse and keyboard.',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2023/03/use-iphone-or-ipad-touch-as-computer.html',
    false,
    false,
    false,
    '{"keyword":"USEIPHONEOR","hint":"Read \"Use the iPhone or iPad Touch as a computer mo...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2023/03/use-iphone-or-ipad-touch-as-computer.html'
);

-- Task 41: How to save a web page to a PDF file
INSERT INTO public.tasks (
    title,
    description,
    points,
    category,
    is_active,
    link_url,
    verification_required,
    is_featured,
    is_repeatable,
    icon_name
)
SELECT 
    'Read, Like & Comment: How to save a web page to a PDF file',
    'Visit this article on BytSphere, read through, leave a like, and post a thoughtful comment. Find the secret verification keyword to claim your 50 points reward.',
    50,
    'article',
    true,
    'https://www.bytsphere.name.ng/2020/09/how-to-save-web-page-to-pdf-file.html',
    false,
    false,
    false,
    '{"keyword":"HOWTOSAVE","hint":"Read \"How to save a web page to a PDF file...\", like & drop a comment to find the keyword."}'
WHERE NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE link_url = 'https://www.bytsphere.name.ng/2020/09/how-to-save-web-page-to-pdf-file.html'
);