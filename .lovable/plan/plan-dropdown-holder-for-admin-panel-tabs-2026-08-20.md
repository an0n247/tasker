# Plan - Dropdown Holder for Admin Panel Tabs

The user wants to see how the Admin Panel looks if the navigation tabs are moved into a dropdown holder instead of being displayed as a horizontal/wrapping list.

## Proposed Changes

### UI Components

#### Admin Panel
- Modify `src/components/AdminPanel.tsx`:
    - Import `DropdownMenu`, `DropdownMenuContent`, `DropdownMenuItem`, `DropdownMenuTrigger` from `@/components/ui/dropdown-menu`.
    - Import `Button` from `@/components/ui/button`.
    - Import `ChevronDown` from `lucide-react`.
    - Add internal state to manage the active tab if `Tabs` doesn't handle the controlled state automatically with the dropdown (though it should).
    - Replace the `TabsList` (which is currently a flexible wrap grid) with a dropdown menu.
    - The dropdown trigger should show the currently selected tab's label and icon.
    - Keep the `Tabs` component as the wrapper to maintain the `TabsContent` functionality, but hide the default `TabsList` UI or replace its logic.

## Technical Details
- The `Tabs` component from Radix (shadcn) usually expects `TabsTrigger` inside `TabsList`. If we use a `DropdownMenu`, we need to ensure the active value is synced. 
- A better approach might be a controlled `Tabs` component where the dropdown selection updates the `value` prop of the `Tabs` component.
- Visual style: The dropdown will be a premium violet-themed button (primary color) to match the Earn Pal aesthetic.

## Verification Plan
- Simulate desktop and mobile viewports.
- Verify that clicking an item in the dropdown correctly switches the visible content below.
- Verify the dropdown trigger updates its label to reflect the current section.
