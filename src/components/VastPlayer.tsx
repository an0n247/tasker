import React, { useEffect, useRef } from "react";
import videojs from "video.js";
import "video.js/dist/video-js.css";

// Importing these as side effects since they extend videojs
import "videojs-contrib-ads";
import "videojs-ima";
import "videojs-ima/dist/videojs.ima.css";

// Extend Video.js type to include IMA plugin
declare module "video.js" {
  interface Player {
    ima: (options: any) => void;
  }
}

interface VastPlayerProps {
  vastTagUrl: string;
  onAdComplete: () => void;
  onAdError: (error: any) => void;
  onAdStarted?: () => void;
}

const VastPlayer: React.FC<VastPlayerProps> = ({
  vastTagUrl,
  onAdComplete,
  onAdError,
  onAdStarted,
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const playerRef = useRef<any>(null);

  useEffect(() => {
    if (!videoRef.current) return;

    // Initialize Video.js player
    const player = videojs(videoRef.current, {
      controls: true,
      autoplay: true,
      muted: false,
      fluid: true,
      preload: "auto",
      responsive: true,
    });

    playerRef.current = player;

    // IMA options
    const options = {
      adTagUrl: vastTagUrl,
      showCountdown: true,
      debug: false,
      // Ensure the container is correctly sized
      adWillAutoPlay: true,
      adWillPlayMuted: false,
    };

    // Initialize IMA plugin
    try {
      (player as any).ima(options);

      const startAds = () => {
        try {
          (player as any).ima.initializeAdDisplayContainer();
          (player as any).ima.requestAds();
          player.off("play", startAds);
        } catch (err) {
          console.error("Error starting ads:", err);
          onAdError(err);
        }
      };

      player.on("play", startAds);

      // IMA events
      player.on("ads-ad-started", () => {
        console.log("VAST: Ad started");
        onAdStarted?.();
      });

      player.on("ads-alladscompleted", () => {
        console.log("VAST: All ads completed");
        onAdComplete();
      });

      // Also listen for content resume which usually happens after an ad finishes
      player.on("ads-ad-ended", () => {
        console.log("VAST: Ad ended");
      });

      player.on("ads-error", (event: any) => {
        console.error("VAST: Ads error:", event.adsError);
        onAdError(event.adsError);
      });

      // Fallback for empty VAST tags (no-fill)
      player.on("ads-manager-loaded", () => {
        console.log("VAST: Ads manager loaded");
      });
    } catch (e) {
      console.error("VAST: Error initializing IMA:", e);
      onAdError(e);
    }

    return () => {
      if (playerRef.current) {
        playerRef.current.dispose();
      }
    };
  }, [vastTagUrl, onAdComplete, onAdError, onAdStarted]);

  return (
    <div data-vjs-player className="w-full h-full">
      <video
        ref={videoRef}
        className="video-js vjs-big-play-centered w-full h-full rounded-xl overflow-hidden"
        playsInline
      />
    </div>
  );
};

export default VastPlayer;
