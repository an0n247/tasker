# Plan - Fix Session Persistence and Navigation Redirects

The user is experiencing session logout issues upon page refresh. This is often caused by a hydration mismatch where the router or components check the session before Supabase has initialized its state from storage, or due to redirects in `beforeLoad` firing before the client-side session is fully restored.

## User Review Required

> [!IMPORTANT]
> I have identified that the session is actually present in your browser's local storage, but the app redirects you to the login page before it can read it. I will implement a more robust session check to prevent these unwanted logouts.

## Proposed Changes

### 1. Refine Authentication Redirects
- Update `beforeLoad` in `src/routes/dashboard.tsx` and other protected routes to use a more resilient session check.
- Currently, `supabase.auth.getSession()` is called immediately. If this runs before the client has finished loading the session from `localStorage`, it might return `null` and trigger a redirect.
- We will ensure the session check waits for initialization or handle the "loading" state of the session more gracefully.

### 2. Standardize Auth Callback (Internal)
- Ensure the Supabase client configuration in `src/integrations/supabase/client.ts` correctly handles `persistSession: true` (already present) and that any `onAuthStateChange` listeners are properly managed.

### 3. Update Auth Page Logic
- Improve the `beforeLoad` logic in `src/routes/auth.tsx` to prevent redirecting *away* from auth if the session is still in an indeterminate state.

## Technical Details

- **File**: `src/routes/dashboard.tsx`
  - Modify `beforeLoad` to potentially retry or wait briefly if `getSession()` returns null initially during hydration.
- **File**: `src/routes/index.tsx`
  - Ensure the landing page doesn't prematurely redirect to `/dashboard` based on a stale or uninitialized session.
- **File**: `src/routes/__root.tsx`
  - Add a global listener for auth state changes to synchronize the UI faster when the session is restored from storage.

## Verification Plan

- **Automated Tests**:
  - Run a Playwright script to:
    1. Log in to the application.
    2. Verify the dashboard is visible.
    3. Refresh the page.
    4. Confirm the user remains on the dashboard and is not redirected to `/auth`.
- **Manual Verification**:
  - Inspect the browser console for any "Unauthorized" errors from server functions during refresh.
  - Verify that the `sb-*-auth-token` remains in `localStorage` after refresh.
