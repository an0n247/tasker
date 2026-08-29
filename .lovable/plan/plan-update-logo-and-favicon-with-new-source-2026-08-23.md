# Plan - Update Logo and Favicon with New Source

The user provided a new source image `IMG_0626.PNG` and requested the logo to be "full rounded" with no black background or "box inside a circle" effect. I will re-process the assets using this new source to ensure the highest quality and correct transparency.

## Technical Details

- **Image Processing**:
  - Use Python and PIL to process `user-uploads://IMG_0626.PNG`.
  - Tighten the crop to the gold circle's edge.
  - Remove the black background by setting the alpha channel based on pixel intensity (anything very dark becomes transparent).
- **Asset Deployment**:
  - Overwrite `public/logo.png`, `public/favicon.png`, and `public/favicon.ico` with the new transparent versions.
- **Verification**:
  - No code changes are needed in `src/routes/__root.tsx` as it already points to these asset paths.
