import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useLocation } from "@tanstack/react-router";

export function Onboarding() {
  const location = useLocation();
  const [isOpen, setIsOpen] = useState(false);
  const [step, setStep] = useState(1);

  useEffect(() => {
    // Don't show onboarding on auth page
    if (location.pathname === "/auth" || location.pathname.startsWith("/admin")) {
      setIsOpen(false);
      return;
    }

    const checkOnboarding = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;

      const sessionFlag = sessionStorage.getItem(`onboarding_shown_${user.id}`);
      if (sessionFlag === "true") return;

      const hasSeen =
        typeof window !== "undefined" ? localStorage.getItem(`onboarding_seen_${user.id}`) : null;
      if (!hasSeen) {
        setIsOpen(true);
        sessionStorage.setItem(`onboarding_shown_${user.id}`, "true");
      }
    };
    checkOnboarding();
  }, [location.pathname]);

  const finish = () => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user && typeof window !== "undefined")
        localStorage.setItem(`onboarding_seen_${user.id}`, "true");
      setIsOpen(false);
    });
  };

  const steps = [
    {
      title: "Welcome to Noble Gain!",
      description:
        "Start earning points today by completing simple tasks, referring friends, and participating in our daily activities.",
    },
    {
      title: "Earn & Redeem",
      description:
        "Points can be redeemed for gift cards, merchandise, and exclusive rewards. The more you earn, the better the rewards!",
    },
    {
      title: "Daily Streaks",
      description:
        "Log in every day to maintain your streak and earn bonus points. Don't break the chain!",
    },
  ];

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogContent className="w-[calc(100%-2rem)] sm:max-w-lg rounded-[1.5rem] md:rounded-[2.5rem] border-none shadow-2xl p-6 md:p-10 mx-auto bg-card max-h-[90dvh] overflow-y-auto">
        <DialogHeader className="space-y-3 md:space-y-6 text-center">
          <DialogTitle className="text-xl md:text-3xl font-black tracking-tight text-foreground uppercase">
            {steps[step - 1]?.title || "Welcome"}
          </DialogTitle>
          <DialogDescription className="text-muted-foreground font-medium text-sm md:text-xl leading-relaxed">
            {steps[step - 1]?.description || ""}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter className="mt-6 md:mt-10 flex flex-row items-center justify-center gap-3">
          {step > 1 && (
            <Button
              variant="ghost"
              onClick={() => setStep(step - 1)}
              className="font-black uppercase tracking-widest text-xs rounded-xl h-10 md:h-12 px-6"
            >
              Back
            </Button>
          )}
          {step < steps.length ? (
            <Button
              onClick={() => setStep(step + 1)}
              className="font-black uppercase tracking-widest text-xs rounded-xl h-10 md:h-12 px-8 shadow-lg shadow-primary/20 hover:scale-[1.02] active:scale-[0.98] transition-all"
            >
              Next
            </Button>
          ) : (
            <Button
              onClick={finish}
              className="font-black uppercase tracking-widest text-xs rounded-xl h-10 md:h-12 px-8 shadow-lg shadow-primary/20 hover:scale-[1.02] active:scale-[0.98] transition-all"
            >
              Get Started
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
