# Plan - Update Logo and Favicon

Update the site's logo and favicon with the user-uploaded image.

## Proposed Changes

### Assets
- Create a new CDN asset from the uploaded image `user-uploads://WhatsApp_Image_2026-08-20_at_06.37.20.jpg` to replace the existing `logo.png` usage via an asset pointer.
- Replace the physical `public/logo.png` file (for root/meta references that require direct paths).
- Replace the physical `public/favicon.ico` file.

### Implementation Steps
1. Create a new asset pointer for the new logo.
2. Update references to `logo.png` in the project to use the new asset pointer where appropriate.
3. Overwrite `public/logo.png` and `public/favicon.ico` with the new image (using `cp` to ensure direct paths work).
4. Verify the new logo appears on the landing page, navigation, and dashboard.

## Technical Details
- Use `lovable-assets create` for the new logo pointer.
- Use `cp /mnt/user-uploads/WhatsApp_Image_2026-08-20_at_06.37.20.jpg public/logo.png`.
- Use `cp /mnt/user-uploads/WhatsApp_Image_2026-08-20_at_06.37.20.jpg public/favicon.ico` (Browser usually handles high-res PNG as favicon fine if named .ico or updated in link tag).
