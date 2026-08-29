# Plan - Optimize Logo and Favicon

The goal is to update the site's logo and favicon to ensure the circular design "fills" the space properly, avoiding a "box inside a circle" appearance. This will be achieved by cropping the source image tightly to the content and applying transparency to the background.

## Technical Details

- **Image Processing**:
  - Use Python and PIL to process `user-uploads://icon.jpg`.
  - Crop the image tightly to the bounding box of the circular logo and crown.
  - Apply an alpha channel to make the black background transparent.
  - Ensure the circle touches the left and right edges of the image to maximize its size in the browser tab.
- **Asset Deployment**:
  - Save the processed image as `public/logo.png`.
  - Generate a multi-resolution `public/favicon.ico` from the processed image.
  - Update `public/favicon.png` for consistency.
- **Routing & Metadata**:
  - Verify `src/routes/__root.tsx` correctly references the updated assets.

## User Review Required

> [!IMPORTANT]
> The new favicon will include the crown element. To make the circle "fill" the space as much as possible, the crown might stick out slightly or the circle might be slightly smaller than a full-bleed square to accommodate it. I have opted for a transparent background which will eliminate the "box" look regardless.
