---
name: Disable domain redirect and apply visual edit
description: Remove forced redirection to earnpal.qd.je and update the transport span in the Navigation component.
type: preference
---

# Plan - Disable Domain Redirect and Apply Visual Edit

The user wants to allow the site to work independently on any domain (e.g., Lovable preview URLs) instead of forcing a redirect to the custom domain `earnpal.qd.je`. Additionally, a visual text edit is requested for a transport span in the navigation component.

## User Review Required

> [!IMPORTANT]
> This change will stop automatic redirects to `https://earnpal.qd.je`. The site will now be accessible from any valid URL (including preview links) without being pushed to the primary domain.

## Proposed Changes

### Frontend Navigation
- Update the transport span in `src/components/Navigation.tsx` to reflect the requested visual text edit.

### Routing Logic
- Remove the `beforeLoad` hook in `src/routes/__root.tsx` that identifies and redirects Lovable preview URLs, `www` prefixes, and insecure HTTP traffic to the primary domain.

## Technical Details

### `src/components/Navigation.tsx`
- Replace the content of the `<span>` element on line 1 (the neutral transport anchor) with the verbatim text provided in the request.

### `src/routes/__root.tsx`
- Clear the logic within the `beforeLoad` function of the root route definition.
- Keep the `head` metadata fallbacks to ensure SEO tags still have a valid default origin when `window` is undefined (e.g., during SSR).
