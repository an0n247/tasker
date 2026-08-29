# Plan - Add VAST Ad Support to Video Tasks

The goal is to integrate VAST (Video Ad Serving Template) support for the "Watch Ads" task. This allows the application to fetch and play standard video ads from third-party ad servers, providing a more professional ad-watching experience for users.

## User Review Required

> [!IMPORTANT]
> The implementation will use a standard VAST player. You will need to provide a VAST XML URL from your ad provider (like Google AdSense/Ad Manager or another provider) when creating the task in the Admin Panel.

- Does the user have a specific VAST provider in mind? (Defaulting to a generic VAST player integration).
- Should the points still be awarded only after the full count (e.g., 10 ads) is reached, or per ad? (Maintaining the current "all-at-once" logic unless specified otherwise).

## Proposed Changes

### Database & Backend
- Add `vast_tag_url` column to the `tasks` table to store the ad tag.
- Update `record_video_watch` RPC to be slightly more resilient (though logic remains mostly the same).

### Admin Panel
- Update `TasksManager.tsx` to include an input for "VAST Tag URL" when the category is "Videos".
- Ensure the `vast_tag_url` is saved to the database.

### User Interface
- Create a `VastPlayer` component using `video.js` and `videojs-ima` (or a similar lightweight VAST library).
- In `_authenticated.earn.tsx`, when a user clicks "Watch Ad":
    - Open a modal with the `VastPlayer`.
    - Once the ad finishes playing, call the `record_video_watch` RPC.
    - Prevent closing the modal until the ad is complete or a skip threshold is met (if allowed by the VAST tag).

## Technical Details

### VAST Player Integration
I'll use `video.js` with the `videojs-ima` plugin, which is the industry standard for VAST/IMA ads.

### New Components
- `src/components/VastPlayer.tsx`: A reusable VAST video player component.
- `src/components/VastAdModal.tsx`: A modal wrapper to show the ad player over the Earn page.

### Dependencies to add
- `video.js`
- `videojs-contrib-ads`
- `videojs-ima`

### Security & Integrity
- The `record_video_watch` RPC already has a `SECURITY DEFINER` and checks the user's session.
- We will add a client-side verification to ensure the ad was actually watched (event listeners on the VAST player) before calling the RPC.
