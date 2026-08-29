# Plan: Unified View for Completed Tasks

Modify the Earn Points page so that when the "Completed" tab is active, all finished tasks are displayed in a single, un-categorized list, while keeping categories available for "Available" tasks.

## User Review Required

> [!IMPORTANT]
> - Do you want the category icons/labels to still be visible on the individual task cards within the unified "Completed" view, or should they be hidden entirely?

## Proposed Changes

### Earn Points Page (`src/routes/_authenticated.earn.tsx`)

- **Logic Update**: Modify `filteredTasks` to ignore the `activeCategory` state when `activeStatus` is set to "completed".
- **UI Update**: Conditionally hide the category filter buttons (All, Social, Surveys, Videos) when the "Completed" tab is active.
- **Visual Refinement**: Ensure the grid layout remains consistent and responsive when displaying the unified list.

## Technical Details

- Update the filter logic:
  ```typescript
  const filteredTasks = (tasks as any[])?.filter((t: any) => {
    const isCompleted = t.status === "verified";
    const matchesStatus = activeStatus === "completed" ? isCompleted : !isCompleted;
    // Only apply category filter if we are looking at available tasks
    const matchesCategory = activeStatus === "completed" || activeCategory === "All" || t.category === activeCategory;
    return matchesStatus && matchesCategory;
  });
  ```
- Wrap the category filter buttons in a conditional: `{activeStatus === "available" && (...)}`.
