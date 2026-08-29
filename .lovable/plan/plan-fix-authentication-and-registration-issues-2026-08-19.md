# Plan: Fix Authentication and Registration Issues

## Problem
1.  **Logout Redirection:** Users are not redirected to the login/landing page correctly after logging out.
2.  **Registration Error:** New users are seeing a database error during signup.
3.  **Visual Text Edits:** A requested text edit needs to be addressed (though it appears to be a no-op).

## Proposed Changes

### 1. Authentication
-   **Logout Redirect:** Update `handleLogout` in `src/components/Navigation.tsx` to use `router.navigate` or `window.location.href` to ensure the user is taken to the landing page or login screen after sign out.
-   **Session Persistence:** Verify `src/routes/__root.tsx` correctly handles session recovery and cleanup for transient sessions.

### 2. Database (Registration Fix)
-   **Harden `handle_new_user` Trigger:** 
    -   Update the trigger function to be more resilient.
    -   Ensure `referral_code` defaults to `username`.
    -   Add `regexp_replace` to clean usernames from invalid characters.
    -   Use `SECURITY DEFINER` and set `search_path = public` for security.
    -   Add better conflict handling for profile creation.

### 3. Visual Text Edits
-   **Review Request:** The user requested changing `\u2063` to `\u2063`. Since these are identical invisible characters, I will confirm this is a no-op or check if there was a typo in the request.

## Technical Details
-   **Migration:** I will use `supabase--migration` to update the `handle_new_user` function.
-   **Navigation:** I will use `router.navigate` from TanStack Router if possible, or `window.location.href` for a full reload to clear state.

## Verification Plan
-   **Logout:** Test the logout button and verify redirection to `/`.
-   **Signup:** Attempt to create a new user and verify the profile is created without error.
-   **Admin Access:** Verify the admin account can still log in and access the admin panel.
