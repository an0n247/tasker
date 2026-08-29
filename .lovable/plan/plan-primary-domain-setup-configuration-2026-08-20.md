# Plan: Primary Domain Setup & Configuration

Configure the application to prioritize `earnpal.qd.je` as the primary domain and provide DNS instructions.

## Technical Details

- **DNS Configuration**: To point the domain to the app, a CNAME record must be created at the domain provider.
- **Client-side Logic**: Ensure the root route handles redirects from legacy domains (like the preview URL) to the primary domain.
- **Metadata**: Update canonical tags and Open Graph metadata to reflect the new domain.

## Steps

1. **Verify Redirect Logic**: Ensure `src/routes/__root.tsx` correctly redirects `www.earnpal.qd.je` and insecure `http` requests to `https://earnpal.qd.je`.
2. **Metadata Audit**: Double-check `src/routes/index.tsx` and other content routes to ensure `og:image` and canonical URLs use the new primary domain.
3. **DNS Instructions**: Provide the user with the exact CNAME/A records needed for their domain provider (`qd.je`).
4. **Visual Edit**: Locate and address the invisible span mentioned in the visual edit request (likely a transport marker).

## User Instructions (DNS Setup)

To make `earnpal.qd.je` work, please add the following record to your DNS settings at your domain provider:

- **Type**: CNAME
- **Host**: earnpal
- **Value**: `id-preview--6935d9db-d3e9-473c-9040-7c3d7835abcd.lovable.app` (or your primary Lovable deployment URL)

If you are using a top-level domain (e.g., just `earnpal.com`), you might need an **ALIAS** or **ANAME** record instead.
