# Plan - Fix Session Persistence and Login Redirect Loop

The user is reporting that they cannot log in again, as the application keeps redirecting them back to the login page even after a successful login attempt. This typically indicates a race condition between the authentication state hydration and the route's `beforeLoad` protection, or a misconfigured `onAuthStateChange` listener that triggers unnecessary redirects.

## Proposed Changes

### 1. Fix Root Route Auth Listener
- **File**: `src/routes/__root.tsx`
- **Change**: Refine the `onAuthStateChange` logic. The current implementation might be triggering a `router.invalidate()` and navigation to `/auth` prematurely during the initial session recovery or when the session is still being established.
- **Goal**: Ensure it only redirects to `/auth` when a user explicitly signs out, not when the app starts up without an existing session (which is handled by route guards).

### 2. Toughen Dashboard Route Guard
- **File**: `src/routes/dashboard.tsx`
- **Change**: Improve the `beforeLoad` check. The current logic has a manual 100ms timeout retry which is fragile. 
- **Goal**: Use a more robust check that waits for the session to be truly initialized or use the TanStack Router's ability to await a session check properly.

### 3. Stabilize Auth Callback
- **File**: `src/routes/auth.callback.tsx`
- **Change**: Ensure the callback handles the initial session correctly and doesn't conflict with the global root listener.

### 4. General Auth Flow Cleanup
- Ensure `src/routes/auth.tsx` correctly redirects to the intended destination after login.

## Technical Details
- The redirect loop often happens if `beforeLoad` runs before Supabase has hydrated the session from local storage.
- TanStack Start's SSR might also be conflicting with client-side only session data.

## Steps
1. Modify `src/routes/__root.tsx` to handle `SIGNED_OUT` events more carefully.
2. Update `src/routes/dashboard.tsx` `beforeLoad` to be more resilient to hydration delays.
3. Verify the fix by simulating a login flow.
