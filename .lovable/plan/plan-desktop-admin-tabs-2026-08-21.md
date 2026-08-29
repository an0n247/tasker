# Plan - Desktop Admin Tabs

Convert the Admin Panel tool selection from a dropdown to visible tabs on desktop, while preserving the dropdown for mobile screens.

## Proposed Changes

### UI Components
#### [AdminPanel.tsx](src/components/AdminPanel.tsx)
- Import `TabsList` and `TabsTrigger` from `@/components/ui/tabs`.
- Update the navigation section to use responsive visibility:
  - Wrap the existing `DropdownMenu` in a `md:hidden` container.
  - Add a `TabsList` wrapped in a `hidden md:flex` container.
  - Apply consistent styling to the `TabsList` and `TabsTrigger` to match the project's visual language (Violet-600, font-black, rounded-2xl).

## Technical Details
- Use Tailwind's `hidden md:flex` and `md:hidden` classes for seamless switching.
- Ensure the `TabsList` is scrollable or wraps if the number of tabs exceeds viewport width on smaller desktop screens (though 8 tabs should fit).
- Match the `TabsTrigger` styling with the existing `DropdownMenuItem` aesthetics.

## Verification Plan
- **Manual Verification**: 
  - Open the Admin Panel on a desktop browser and verify all tabs are visible.
  - Resize the browser to mobile width and verify the dropdown appears instead.
  - Click through all tabs in both modes to ensure they correctly switch content.
