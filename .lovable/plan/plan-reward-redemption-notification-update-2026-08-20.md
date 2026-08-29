---
title: Reward Redemption Notification
description: Update the reward redemption confirmation message to inform users that rewards will be sent to their registered email address.
---

# Plan - Reward Redemption Notification Update

The user wants to add a specific notification message after a user confirms a reward redemption, stating that the reward will be sent to their registered email address after confirmation.

## Proposed Changes

### Frontend

#### [src/routes/_authenticated.redeem.tsx](src/routes/_authenticated.redeem.tsx)
- Update the `toast.success` message in the `handleRedeem` function.
- Current message: `"Redemption request submitted! Points have been deducted."`
- New message: `"Redemption request submitted! Your reward will be sent to your registered email address once confirmed by our team."` (or similar phrasing as requested).
- Optional: Add a descriptive text inside the confirmation `Dialog` as well to set expectations before the user clicks confirm.

## Verification Plan

### Automated Tests
- I will check if the toast message update is correctly applied.
- Since I cannot easily trigger a database RPC call in a headless test without a full environment, I will perform a visual check of the code.

### Manual Verification
- Navigate to the "Redeem" page.
- Select a reward.
- Click "Confirm Redemption".
- Verify the success toast message contains the new text.
