# Fix: logged out after refresh

On a hard refresh of `/dashboard`, the app bounces to `/auth?redirect=%2Fdashboard`. The protected-route guard in `src/routes/_authenticated.tsx` calls `supabase.auth.getSession()` inside `beforeLoad`, which also runs during server-side rendering. On the server there is no browser storage, so the session always looks missing and the redirect fires before the browser ever gets a chance to restore the saved session.

The "Remember me" cleanup in `src/routes/__root.tsx` can also sign users out on a fresh browser start, which is why closing and reopening the browser logs them out.

## What will change

1. **Protected route guard (`src/routes/_authenticated.tsx`)**
   - Skip the session check during server rendering; only enforce it in the browser.
   - In the browser, wait for the Supabase client to finish restoring the stored session before deciding to redirect (short retry instead of an immediate verdict).
   - Keep the `redirect` search param so a genuinely signed-out user still lands back on the page they wanted.

2. **Session persistence defaults (`src/routes/__root.tsx`)**
   - Stop the transient-session cleanup from signing users out on browser restart. Sessions persist across refresh and browser close until the user signs out manually.
   - Keep the auth listener for sign-out redirects and router invalidation only.

3. **Remember me (`src/routes/auth.tsx`)**
   - Since sessions now always persist until manual sign-out, remove the transient flag writing so the two systems can't fight each other. The checkbox stays but no longer forces an early sign-out.

## Verification

- Sign in, land on the dashboard, hard refresh: stays on `/dashboard`, no `/auth` bounce.
- Close the tab and reopen the app: still signed in.
- Sign out manually: redirected to the landing page and `/dashboard` correctly sends you to `/auth`.
