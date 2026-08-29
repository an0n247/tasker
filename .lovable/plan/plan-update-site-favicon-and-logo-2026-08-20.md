# Plan: Update Site Favicon and Logo

The user wants to update the site's logo and favicon across the application using the provided image. Currently, the app uses the `Coins` icon from `lucide-react` as a placeholder logo.

## Proposed Changes

### Assets and Public Files
- Use the uploaded image to create a permanent logo asset.
- Replace `public/favicon.ico` and `public/logo.png` with the new image.

### UI Components
- **`src/components/Navigation.tsx`**: Replace the `Coins` icon with an `<img>` tag using the new logo asset in both mobile and desktop navigation headers.
- **`src/routes/__root.tsx`**: 
    - Replace the `Coins` icon in the `NotFoundComponent` and `ErrorComponent` with the new logo.
    - Update the `head` links to ensure the favicon and OG images are consistent.
- **`src/routes/auth.tsx`**: Replace the `Coins` icon in the auth page with the new logo.
- **`src/routes/index.tsx`**: Update any logo references in the landing page (if any exist beyond the shared Navigation).
- **`src/routes/_authenticated.dashboard.tsx`**: Update logo references in the dashboard if necessary.

## Technical Details
- Create `src/assets/logo.png.asset.json` pointing to the new logo.
- The `Coins` icon is used with specific classes (e.g., `h-7 w-7`, `text-primary`). The new `<img>` tags will be styled to match these dimensions and alignment.
- Verify that `public/favicon.ico` works correctly as a standard icon file.

## Verification Plan
- Check the live preview to confirm the new logo appears in the sidebar, header, auth pages, and error pages.
- Verify the favicon is correctly loaded by the browser.
- Run a headless check to ensure no broken image links exist.
