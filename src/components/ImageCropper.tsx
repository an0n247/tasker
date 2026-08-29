import React, { useState, useCallback } from "react";
import Cropper from "react-easy-crop";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { Crop, ZoomIn } from "lucide-react";

export interface ImageCropperProps {
  image?: string;
  imageSrc?: string;
  onCropComplete: (croppedImage: Blob) => void;
  onCancel?: () => void;
  onClose?: () => void;
  open?: boolean;
  isOpen?: boolean;
}

export function ImageCropper({
  image,
  imageSrc,
  onCropComplete,
  onCancel,
  onClose,
  open,
  isOpen,
}: ImageCropperProps) {
  const activeImage = image || imageSrc || "";
  const isModalOpen = open ?? isOpen ?? false;
  const handleClose = onCancel || onClose || (() => {});

  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<any>(null);

  const onCropChange = (newCrop: { x: number; y: number }) => {
    setCrop(newCrop);
  };

  const onZoomChange = (newZoom: number) => {
    setZoom(newZoom);
  };

  const onCropCompleteCallback = useCallback((_croppedArea: any, pixelCrop: any) => {
    setCroppedAreaPixels(pixelCrop);
  }, []);

  const createImage = (url: string): Promise<HTMLImageElement> =>
    new Promise((resolve, reject) => {
      const img = new Image();
      img.addEventListener("load", () => resolve(img));
      img.addEventListener("error", (error) => reject(error));
      img.setAttribute("crossOrigin", "anonymous");
      img.src = url;
    });

  const getCroppedImg = async (src: string, pixelCrop: any): Promise<Blob | null> => {
    const img = await createImage(src);
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");

    if (!ctx || !pixelCrop) return null;

    canvas.width = pixelCrop.width;
    canvas.height = pixelCrop.height;

    ctx.drawImage(
      img,
      pixelCrop.x,
      pixelCrop.y,
      pixelCrop.width,
      pixelCrop.height,
      0,
      0,
      pixelCrop.width,
      pixelCrop.height,
    );

    return new Promise((resolve) => {
      canvas.toBlob(
        (blob) => {
          resolve(blob);
        },
        "image/jpeg",
        0.92,
      );
    });
  };

  const handleCrop = async () => {
    try {
      if (!activeImage || !croppedAreaPixels) return;
      const croppedImage = await getCroppedImg(activeImage, croppedAreaPixels);
      if (croppedImage) {
        onCropComplete(croppedImage);
      }
    } catch (e) {
      console.error("Error cropping image:", e);
    }
  };

  return (
    <Dialog open={isModalOpen} onOpenChange={(v) => !v && handleClose()}>
      <DialogContent className="sm:max-w-[480px] rounded-3xl border border-hairline bg-ink-2 text-ink-fg shadow-2xl overflow-hidden p-6 gap-5 backdrop-blur-2xl">
        <DialogHeader className="text-left space-y-1">
          <DialogTitle className="text-lg font-black tracking-tight text-ink-fg flex items-center gap-2">
            <Crop className="size-5 text-gold" />
            Adjust Profile Picture
          </DialogTitle>
          <DialogDescription className="text-xs text-ink-muted font-medium">
            Drag to reposition and adjust the slider to scale your avatar.
          </DialogDescription>
        </DialogHeader>

        <div className="relative h-[320px] w-full bg-black/60 overflow-hidden rounded-2xl border border-hairline">
          {activeImage && (
            <Cropper
              image={activeImage}
              crop={crop}
              zoom={zoom}
              aspect={1}
              onCropChange={onCropChange}
              onCropComplete={onCropCompleteCallback}
              onZoomChange={onZoomChange}
              cropShape="round"
              showGrid={false}
            />
          )}
        </div>

        <div className="space-y-2 bg-ink rounded-2xl p-4 border border-hairline">
          <div className="flex items-center justify-between text-xs font-bold text-ink-muted">
            <span className="flex items-center gap-1.5">
              <ZoomIn className="size-3.5 text-gold" /> Zoom Level
            </span>
            <span className="font-mono text-ink-fg">{zoom.toFixed(1)}x</span>
          </div>
          <Slider
            value={[zoom]}
            min={1}
            max={3}
            step={0.1}
            onValueChange={(val) => setZoom(val[0] ?? 1)}
            className="cursor-pointer"
          />
        </div>

        <DialogFooter className="gap-2 sm:gap-0 flex flex-row justify-end">
          <Button
            variant="outline"
            onClick={handleClose}
            className="rounded-xl font-bold h-11 border-hairline bg-ink hover:bg-ink-3 text-ink-fg text-xs px-5 cursor-pointer"
          >
            Cancel
          </Button>
          <Button
            onClick={handleCrop}
            className="rounded-xl font-black h-11 bg-gold text-ink hover:bg-gold-soft text-xs px-6 cursor-pointer shadow-md shadow-gold/10 ml-2"
          >
            Apply & Upload
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
