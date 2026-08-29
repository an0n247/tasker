# Plan - Secure Admin Access & Animated Warning

Implement a robust access denial screen for non-admin users attempting to access the `/admin` route. This replaces the current immediate redirect with a user-friendly, animated warning message that prevents any admin content from leaking.

## User Review Required

> [!IMPORTANT]
> - The warning will be triggered for any user who is authenticated but lacks either the `admin` or `moderator` role.
> - The "Return to Dashboard" button will direct users back to the main authenticated landing page.

- Does the "Access Denied" screen need to include a way to request access, or should it just be a dead-end with a return button?
- Do you have a preferred animation style (e.g., a pulsing lock icon, a sliding alert)?

## Proposed Changes

### 🔐 Auth & Security
#### [src/routes/_authenticated.admin.tsx]
- Remove the `beforeLoad` redirect for non-admins to allow the component to render the warning state.
- Keep the `beforeLoad` redirect for unauthenticated users to `/auth`.
- Pass role information down to the component or handle role check within the route component.

### 🎨 UI & Components
#### [src/components/admin/AccessDenied.tsx] (New)
- Create a dedicated component for the access denial state.
- Include a large, animated "ShieldAlert" or "Lock" icon using `lucide-react`.
- Add a bold "Access Denied" heading and a descriptive message.
- Add a "Return to Dashboard" button using the project's standard `Button` component.
- Apply `framer-motion` for smooth, professional entry animations.

#### [src/routes/_authenticated.admin.tsx]
- Modify the component logic to check for `isAdmin` or `isModerator`.
- If the user is authorized, render the existing `AdminPanel`.
- If the user is unauthorized, render the new `AccessDenied` component.
- Ensure no data fetching (like stats or audit logs) happens if the user is unauthorized.

## Technical Details
- Role verification will still use the `has_role` RPC for security.
- The `AccessDenied` component will use Tailwind's `animate-in` utilities or `framer-motion` for the "big, animated" requirement.
- The `AdminPanel` component will be lazily evaluated or conditionally rendered so that its `useQuery` calls (which might fail or leak metadata) never execute for non-admins.

## Validation Plan
- Log in as a standard user and navigate to `/admin` -> verify the animated warning appears and no admin data is loaded.
- Log in as an admin/moderator and navigate to `/admin` -> verify the admin panel loads normally.
- Attempt to access `/admin` while logged out -> verify redirect to `/auth`.
