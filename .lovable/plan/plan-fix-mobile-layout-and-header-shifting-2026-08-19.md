# Plan - Fix Mobile Layout and Header Shifting

The user reported that on mobile, the page seems to be "shifting to one side" and the header is on the other side. This is likely due to how the sidebar and main content padding are handled, especially since we recently implemented a permanent sidebar for desktop. On mobile, we have a top bar and an overlay sidebar, but the main content might still be receiving incorrect padding or is being pushed by elements that should be overlays.

## User Review Required

> [!IMPORTANT]
> I will adjust the mobile header and main content layout to ensure they are centered and properly aligned without shifting.

- **Layout Fix**: I will ensure the main content container in `src/routes/__root.tsx` correctly resets its padding on mobile.
- **Header Alignment**: I will adjust the mobile top bar in `src/components/Navigation.tsx` to ensure it spans the full width and handles its children (menu, logo, profile) with proper centering/spacing.

## Technical Details

### Frontend Changes

#### `src/routes/__root.tsx`
- Refine the `main` tag classes to ensure that `md:pl-72` (the desktop sidebar offset) is strictly applied only on medium screens and up, and that no unexpected margins/paddings are pushing the content on mobile.

#### `src/components/Navigation.tsx`
- Ensure the "Mobile Top Bar" (`md:hidden`) is correctly styled with `w-full` and `left-0` if needed, although it's currently `sticky`.
- Verify the `container` or padding in the mobile top bar matches the main content padding to prevent a staggered look.
- Check if any hidden desktop elements are taking up space on mobile.

### Verification Plan

#### Automated Tests
- Use Playwright to capture screenshots of the dashboard on mobile viewport (e.g., iPhone 12) to verify alignment.
- Inspect the computed styles of the `main` and `header` elements to ensure no unwanted `padding-left` or `margin-left` exists on mobile.

#### Manual Verification
- View the mobile preview and check the alignment of the "Welcome back" text relative to the "Earn Pal" logo in the header.
