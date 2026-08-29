import React from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import VastPlayer from "./VastPlayer";
import { Loader2, AlertCircle } from "lucide-react";
import { toast } from "sonner";

interface VastAdModalProps {
  isOpen: boolean;
  onClose: () => void;
  vastTagUrl: string;
  onComplete: () => void;
  taskTitle: string;
}

const VastAdModal: React.FC<VastAdModalProps> = ({
  isOpen,
  onClose,
  vastTagUrl,
  onComplete,
  taskTitle,
}) => {
  const [error, setError] = React.useState<string | null>(null);
  const [isAdPlaying, setIsAdPlaying] = React.useState(false);

  const handleAdComplete = () => {
    setIsAdPlaying(false);
    toast.success("Ad completed! Crediting points...");
    onComplete();
  };

  const handleAdError = (adError: any) => {
    console.error("Ad Error:", adError);
    setError("Failed to load ad. Please try again later.");
    setIsAdPlaying(false);
  };

  return (
    <Dialog
      open={isOpen}
      onOpenChange={(open) => {
        // Prevent closing while ad is playing unless it's an error
        if ((!open && !isAdPlaying) || error) {
          onClose();
        }
      }}
    >
      <DialogContent className="sm:max-w-[800px] p-0 overflow-hidden bg-black border-none rounded-2xl">
        <DialogHeader className="p-6 bg-card text-card-foreground border-b border-border/50">
          <DialogTitle className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
            Watch Ad: {taskTitle}
          </DialogTitle>
          <DialogDescription className="font-medium">
            Please watch the advertisement completely to earn your points.
          </DialogDescription>
        </DialogHeader>

        <div className="relative min-h-[300px] flex items-center justify-center bg-black aspect-video">
          {error ? (
            <div className="text-center p-8 space-y-4">
              <AlertCircle className="h-12 w-12 text-destructive mx-auto" />
              <p className="text-white font-bold">{error}</p>
              <button
                onClick={onClose}
                className="bg-primary text-primary-foreground px-6 py-2 rounded-xl font-bold"
              >
                Close
              </button>
            </div>
          ) : (
            <VastPlayer
              vastTagUrl={vastTagUrl}
              onAdComplete={handleAdComplete}
              onAdError={handleAdError}
              onAdStarted={() => setIsAdPlaying(true)}
            />
          )}

          {!isAdPlaying && !error && (
            <div className="absolute inset-0 flex items-center justify-center bg-black/60 z-10">
              <div className="text-center text-white space-y-2">
                <Loader2 className="h-10 w-10 animate-spin mx-auto text-primary" />
                <p className="font-black uppercase tracking-widest text-xs">Loading Ad...</p>
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default VastAdModal;
