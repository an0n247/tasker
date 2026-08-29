# Plan - Increase Mobile Task Card Height and Legibility

The goal is to increase the height and font sizes of task cards on mobile devices to ensure task instructions are readable and not "too tiny." This affects the `Earn` page and the `Featured Tasks` on the `Dashboard`.

## Proposed Changes

### 1. Update Earn Page Task Cards
- Modify `src/routes/_authenticated.earn.tsx` to adjust mobile styling for task cards.
- Increase `CardHeader` padding on mobile.
- Increase font sizes for `Badge`, `CardTitle`, and `CardDescription` on mobile.
- Change `line-clamp-1` to `line-clamp-2` for the description on mobile to allow more text visibility.
- Increase button height on mobile.

### 2. Update Dashboard Featured Task Cards
- Modify `src/routes/_authenticated.dashboard.tsx` to match the mobile styling adjustments.
- Synchronize padding, font sizes, and button heights for consistency with the Earn page.

## Technical Details

### `src/routes/_authenticated.earn.tsx`
- Change `CardHeader` from `p-3 sm:p-4` to `p-5 sm:p-4`.
- Change `Badge` from `text-[8px] sm:text-[10px]` to `text-[10px]`.
- Change `CardTitle` from `text-[13px] sm:text-lg` to `text-[15px] sm:text-lg`.
- Change `CardDescription` from `text-[9px] sm:text-sm line-clamp-1 sm:line-clamp-2` to `text-[11px] sm:text-sm line-clamp-2`.
- Change `Button` height from `h-9 sm:h-11` to `h-10 sm:h-11`.

### `src/routes/_authenticated.dashboard.tsx`
- Apply similar utility class updates to the `featuredTasks` mapping loop.

## Verification Plan

### Visual Inspection
- Use Playwright to capture screenshots at `375x812` (iPhone 12 Pro size) to verify:
    - Text is readable and not "tiny."
    - Cards have enough vertical space for instructions.
    - Layout remains balanced.
