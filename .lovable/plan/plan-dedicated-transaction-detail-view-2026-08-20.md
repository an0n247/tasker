# Plan: Dedicated Transaction Detail View

I will implement a dedicated transaction detail page and a modal-based transaction viewer.

## User Review Required

> [!IMPORTANT]
> The transaction detail view will be accessible via a direct link (e.g., `/transactions?id=...`) and will automatically open a detailed modal for that specific transaction.

## Proposed Changes

### Routes & Navigation
- Update `src/routes/_authenticated.transactions.tsx` to handle a `transactionId` search parameter.
- When the parameter is present, the page will automatically open the transaction detail modal.

### Components & UI
- Create `src/components/TransactionDetailModal.tsx` using the `Dialog` component (Radix UI) for a "normal modal" experience.
- This modal will replace the "flash pop-up" (toast) when clicking notifications or transaction items.
- It will display: Description, Amount, Type, Date, and ID with a clean, modern layout consistent with the Earn Pal design system.

### Integration
- Update `src/components/NotificationsPopover.tsx` to navigate to `/transactions?transactionId={id}` instead of showing a toast or navigating to the generic history.
- Update `src/routes/_authenticated.transactions.tsx` to trigger the modal when the search param is detected.

## Technical Details
- Use TanStack Router's `useSearch` to detect the `transactionId`.
- Use a state-controlled `Dialog` in `src/routes/_authenticated.transactions.tsx` to manage the modal visibility.
- Ensure the modal is deep-linkable so that direct navigation to the URL opens the specific transaction.
