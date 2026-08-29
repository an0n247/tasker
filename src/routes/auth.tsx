import { createFileRoute, useNavigate, useSearch, Link } from "@tanstack/react-router";
import { useState, useEffect, useCallback } from "react";
import { ThemeToggle } from "@/components/ThemeToggle";
import { supabase } from "@/integrations/supabase/client";
import { lovable } from "@/integrations/lovable/index";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Coins,
  Loader2,
  Mail,
  Lock,
  User,
  CheckCircle2,
  ArrowLeft,
  Eye,
  EyeOff,
  Share2,
  Clock,
  RefreshCw,
  Sparkles,
  Inbox,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import { getClientIp } from "@/lib/session-tracking.functions";
import { sendSignupOtp, verifySignupOtp } from "@/lib/signup-otp.functions";
import { z } from "zod";
import { useDebouncedCallback } from "@/hooks/use-debounced-callback";
import { getUsernameStatus, normalizeUsername, toUsernameFieldState } from "@/lib/username-validation";

export const Route = createFileRoute("/auth")({
  head: () => ({
    title: "Secure Login & Registration | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "Access your Noble Gain account or sign up to start earning rewards. Secure login for the most trusted points-earning community.",
      },
      { property: "og:title", content: "Join Noble Gain | Secure Access" },
      {
        property: "og:description",
        content:
          "Sign in to manage your rewards or create a new account and get a 50-point welcome bonus with a referral code!",
      },
      { property: "og:type", content: "website" },
      { property: "og:image", content: "/logo.png" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  validateSearch: (search) =>
    z
      .object({
        redirect: z.string().optional(),
        mode: z.enum(["login", "signup"]).optional(),
        ref: z.string().optional(),
      })
      .parse(search),
  component: AuthPage,
});

function AuthPage() {
  const navigate = useNavigate();
  const search = useSearch({ from: "/auth" });
  const [activeTab, setActiveTab] = useState<"login" | "signup">(
    search.mode || (search.ref ? "signup" : "login"),
  );
  const [loading, setLoading] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [email, setEmail] = useState("");
  const [identifier, setIdentifier] = useState(""); // Can be email or username
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [username, setUsername] = useState("");
  const [error, setError] = useState("");
  const [referralCode, setReferralCode] = useState(search.ref || "");
  const [usernameStatus, setUsernameStatus] = useState<{
    loading: boolean;
    available: boolean | null;
    message: string;
    error: boolean;
  }>({
    loading: false,
    available: null,
    message: "",
    error: false,
  });
  const [referralStatus, setReferralStatus] = useState<{
    loading: boolean;
    owner: string | null;
    error: boolean;
    message: string | null;
  }>({
    loading: false,
    owner: null,
    error: false,
    message: null,
  });
  const [showVerification, setShowVerification] = useState(false);
  const [verificationCode, setVerificationCode] = useState("");
  const [verifyingOtp, setVerifyingOtp] = useState(false);
  const [showReset, setShowReset] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [resetLoading, setResetLoading] = useState(false);
  const [resetSent, setResetSent] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showSignupPassword, setShowSignupPassword] = useState(false);
  const [resending, setResending] = useState(false);
  const [agreedToTerms, setAgreedToTerms] = useState(false);

  useEffect(() => {
    if (!showVerification) return;

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (session?.user) {
        toast.success("Email verified successfully! Welcome to Noble Gain.");
        (supabase.from("analytics_events" as any) as any)
          .insert({
            event_name: "signup_complete",
            metadata: { email, username },
          })
          .then();
        navigate({ to: (search.redirect as any) || "/dashboard" });
      }
    });

    const interval = setInterval(async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (session?.user) {
        toast.success("Email verified successfully! Welcome to Noble Gain.");
        navigate({ to: (search.redirect as any) || "/dashboard" });
      }
    }, 3000);

    return () => {
      subscription.unsubscribe();
      clearInterval(interval);
    };
  }, [showVerification, email, username, navigate, search.redirect]);

  useEffect(() => {
    if (search.mode) {
      setActiveTab(search.mode);
    } else if (search.ref) {
      setActiveTab("signup");
    }
  }, [search.mode, search.ref]);

  useEffect(() => {
    if (search.ref) {
      setReferralCode(search.ref);
      validateReferral(search.ref);
    }
  }, [search.ref]);

  const checkUsernameAvailability = useCallback(async (rawValue: string) => {
    const normalized = normalizeUsername(rawValue);

    if (!normalized || normalized.length < 3) {
      setUsernameStatus(toUsernameFieldState(getUsernameStatus(rawValue)));
      return;
    }

    if (!/^[a-z0-9_]+$/.test(normalized)) {
      setUsernameStatus({
        loading: false,
        available: false,
        error: true,
        message: "Use only letters, numbers, and underscores.",
      });
      return;
    }

    setUsernameStatus({
      loading: true,
      available: null,
      error: false,
      message: "Checking username availability...",
    });

    try {
      const { data, error: rpcError } = await supabase.rpc("check_username_available", {
        _username: normalized,
      });

      if (rpcError) throw rpcError;

      const available = data === true;
      setUsernameStatus({
        loading: false,
        available,
        error: !available,
        message: available ? "Username available." : "Username is already taken.",
      });
    } catch (error) {
      console.error("Username availability check failed:", error);
      setUsernameStatus({
        loading: false,
        available: null,
        error: true,
        message: "Could not verify username availability. Please try again.",
      });
    }
  }, []);

  const validateReferral = async (code: string) => {
    if (!code || code.trim().length < 3) {
      setReferralStatus({ loading: false, owner: null, error: false, message: null });
      return;
    }

    setReferralStatus((prev) => ({ ...prev, loading: true, error: false, message: null }));
    try {
      const { data, error: rpcError } = await supabase.rpc("check_referral_code", {
        _code: code.trim(),
      });

      if (rpcError) throw rpcError;

      const result = Array.isArray(data) ? data[0] : data;

      if (result && result.is_valid) {
        setReferralStatus({
          loading: false,
          owner: result.username,
          error: false,
          message: result.message || `Referrer found: ${result.username}`,
        });
      } else {
        setReferralStatus({
          loading: false,
          owner: null,
          error: true,
          message: result?.message || "This referral code does not exist or is invalid.",
        });
      }
    } catch (err) {
      console.error("Referral validation error:", err);
      setReferralStatus({
        loading: false,
        owner: null,
        error: true,
        message: "Unable to validate referral code. Please try again.",
      });
    }
  };

  const debouncedUsernameCheck = useDebouncedCallback((nextUsername: string) => {
    void checkUsernameAvailability(nextUsername);
  }, 500);

  const debouncedReferralCheck = useDebouncedCallback((nextCode: string) => {
    void validateReferral(nextCode);
  }, 500);

  const handleReferralChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value.replace(/[^a-zA-Z0-9_]/g, "");
    setReferralCode(val);
    debouncedReferralCheck(val);
  };

  const validate = (type: "login" | "signup") => {
    if (type === "login") {
      if (!identifier) {
        setError("Please enter your email or username.");
        return false;
      }
    } else {
      if (!email.includes("@")) {
        setError("Please enter a valid email address.");
        return false;
      }
      if (username.length < 3) {
        setError("Username must be at least 3 characters.");
        return false;
      }
      if (!/^[a-z0-9_]+$/.test(username)) {
        setError("Username can only contain letters, numbers, and underscores.");
        return false;
      }
      if (usernameStatus.loading) {
        setError("Please wait while we verify your username.");
        return false;
      }
      if (usernameStatus.available === false || usernameStatus.error) {
        setError("Please choose an available username.");
        return false;
      }
      if (!fullName) {
        setError("Please enter your full name.");
        return false;
      }
      if (!agreedToTerms) {
        setError("You must agree to the Terms and Conditions.");
        return false;
      }
    }

    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return false;
    }
    setError("");
    return true;
  };

  const handleEmailLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate("login")) return;
    setLoading(true);
    try {
      let loginEmail = identifier.trim();

      if (!loginEmail.includes("@")) {
        const { data, error: rpcError } = await supabase.rpc("lookup_login_email", {
          _username: loginEmail,
        });

        if (rpcError || !data) {
          throw new Error("Incorrect username/email or password.");
        }
        loginEmail = data;
      }

      // The session is stored in localStorage and persists across refreshes and
      // browser restarts until the user signs out manually.
      localStorage.removeItem("noble-gain-session-transient");
      sessionStorage.removeItem("noble-gain-session-active");

      const { error } = await supabase.auth.signInWithPassword({
        email: loginEmail,
        password,
      });

      if (error) throw error;

      navigate({ to: (search.redirect as any) || "/dashboard" });
    } catch (error: any) {
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleEmailSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate("signup")) return;
    setLoading(true);
    setError("");
    try {
      const signupIp = await getClientIp().then((r) => r.ip).catch(() => null);

      const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            username,
            full_name: fullName,
            referral_code_used: referralCode || null,
            fingerprint: (window as any)._ep_fingerprint || null,
            ip_address: signupIp,
          },
        },
      });

      if (signUpError) throw signUpError;

      // Supabase returns a fake "success" (obfuscated user with no identities)
      // when the email is already registered — detect and block it.
      if (signUpData.user && signUpData.user.identities?.length === 0) {
        throw new Error("An account with this email already exists. Please sign in instead.");
      }

      await sendSignupOtp({ data: { email } });

      setVerificationCode("");
      setShowVerification(true);
      toast.success("A secure One-Time Password has been sent to your email.");
    } catch (error: any) {
      setError(error.message || "Unable to send verification code. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async () => {
    const token = verificationCode.trim();
    if (!token || token.length < 6) {
      setError("Enter the 6-digit verification code from your email.");
      return;
    }

    setVerifyingOtp(true);
    setError("");

    try {
      await verifySignupOtp({ data: { email, code: token } });

      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (signInError) throw signInError;

      toast.success("Email verified successfully. Welcome to Noble Gain.");
      navigate({ to: (search.redirect as any) || "/dashboard" });
    } catch (error: any) {
      setError(error.message || "Unable to verify code. Please request a new one.");
    } finally {
      setVerifyingOtp(false);
    }
  };

  const handleResendVerificationLink = async () => {
    setResending(true);
    setError("");
    try {
      const result = await sendSignupOtp({ data: { email } });

      if (result.cooldown > 0) {
        toast.info(`Please wait ${result.cooldown}s before requesting another code.`);
      } else {
        toast.success("A fresh verification code has been sent to your email.");
      }
    } catch (error: any) {
      setError(error.message || "Unable to resend the code.");
    } finally {
      setResending(false);
    }
  };

  const handleGoogleLogin = async () => {
    const result = await lovable.auth.signInWithOAuth("google", {
      redirect_uri: window.location.origin + "/auth/callback",
    });
    if (result.error) {
      setError(result.error.message);
    }
  };

  const handlePasswordReset = async (e: React.FormEvent) => {
    e.preventDefault();
    const input = resetEmail.trim();
    if (!input) {
      setError("Please enter your email or username.");
      return;
    }
    setError("");
    setResetLoading(true);
    try {
      let targetEmail = input;

      if (!targetEmail.includes("@")) {
        const { data } = await supabase.rpc("lookup_login_email", {
          _username: targetEmail,
        });
        targetEmail = (data as string | null) ?? "";
      }

      if (targetEmail) {
        const { error } = await supabase.auth.resetPasswordForEmail(targetEmail, {
          redirectTo: window.location.origin + "/auth",
        });
        if (error) throw error;
      }

      setResetSent(true);
      toast.success("If an account exists, a reset link has been sent.");
    } catch (error: any) {
      setError(error.message);
    } finally {
      setResetLoading(false);
    }
  };

  const shellClass =
    "auth-shell relative min-h-screen w-full px-4 py-0 flex flex-col items-center justify-center bg-background text-foreground sm:px-6 overflow-hidden hero-gradient";

  const Brand = () => (
    <div className="flex items-center justify-center gap-2.5">
      <img src="/logo.png" alt="Noble Gain" className="size-7 sm:size-9 object-contain" />
      <div className="font-black text-xl sm:text-2xl tracking-tighter uppercase text-foreground">
        Noble <span className="text-[#e6c17a]">Gain</span>
      </div>
    </div>
  );

  const BackLink = () => (
    <Link
      to="/"
      className="mb-2 sm:mb-3 inline-flex items-center gap-1.5 text-xs sm:text-sm font-bold text-muted-foreground transition-colors hover:text-primary"
    >
      <ArrowLeft className="h-3.5 w-3.5" />
      Back to home
    </Link>
  );

  if (showVerification) {
    return (
      <div className={cn(shellClass, "px-4 sm:px-6")}>
        <div className="w-full max-w-[94%] sm:max-w-md">
          <BackLink />
          <div className="glass-card rounded-[2rem] p-5 sm:p-7 premium-shadow-lg text-center space-y-4">
            <Brand />

            {/* Rolling Circle Animation with Mail Glow */}
            <div className="py-2 flex flex-col items-center justify-center">
              <div className="relative size-20 sm:size-24 flex items-center justify-center">
                {/* Outer spinning ring */}
                <div className="absolute inset-0 rounded-full border-4 border-gold/20 border-t-gold animate-spin" />
                {/* Secondary counter-spinning faint ring */}
                <div className="absolute inset-2 rounded-full border-2 border-primary/20 border-b-primary animate-spin [animation-direction:reverse] [animation-duration:3s]" />
                {/* Central Glowing Icon */}
                <div className="size-12 sm:size-14 rounded-full bg-gold/15 flex items-center justify-center border border-gold/30 shadow-lg shadow-gold/10">
                  <Mail className="size-6 sm:size-7 text-gold animate-pulse" />
                </div>
              </div>

              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-gold/10 border border-gold/20 text-[11px] font-bold text-gold mt-3">
                <span className="size-1.5 rounded-full bg-gold animate-ping" />
                <span>Waiting for email confirmation...</span>
              </div>
            </div>

            <div>
              <h2 className="text-xl sm:text-2xl font-black tracking-tight text-foreground uppercase">
                Enter Your Code
              </h2>
              <p className="mt-1 text-xs sm:text-sm text-muted-foreground leading-relaxed">
                We sent a 6-digit verification code to{" "}
                <span className="font-bold text-foreground break-all">{email}</span>. Enter it below
                to activate your account.
              </p>
            </div>

            <div className="rounded-2xl border border-border/70 bg-background/80 p-3.5 text-left">
              <Label className="text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground">
                Verification code
              </Label>
              <Input
                value={verificationCode}
                onChange={(e) => setVerificationCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
                placeholder="123456"
                className="mt-2 h-12 rounded-2xl border-border/70 bg-background text-center text-lg font-black tracking-[0.5em]"
                inputMode="numeric"
                autoComplete="one-time-code"
              />
            </div>

            {error && (
              <div className="rounded-2xl bg-destructive/10 p-2.5 text-xs sm:text-sm font-bold text-destructive">
                {error}
              </div>
            )}

            <div className="space-y-2 pt-1">
              <Button
                type="button"
                onClick={handleVerifyOtp}
                disabled={verifyingOtp}
                className="w-full h-11 rounded-2xl bg-gold text-ink hover:bg-gold-soft font-black text-xs sm:text-sm"
              >
                {verifyingOtp ? (
                  <Loader2 className="size-4 animate-spin mr-2" />
                ) : (
                  <CheckCircle2 className="size-4 mr-2" />
                )}
                {verifyingOtp ? "Verifying code..." : "Verify my email"}
              </Button>

              <Button
                type="button"
                variant="outline"
                onClick={handleResendVerificationLink}
                disabled={resending}
                className="w-full h-11 rounded-2xl border-border/70 bg-background text-xs sm:text-sm font-bold glass-card hover:bg-primary/5 transition-colors"
              >
                {resending ? (
                  <Loader2 className="size-4 animate-spin mr-2" />
                ) : (
                  <RefreshCw className="size-3.5 mr-2 text-gold" />
                )}
                {resending ? "Sending code..." : "Resend verification code"}
              </Button>

              <button
                type="button"
                className="w-full text-center text-xs sm:text-sm font-bold text-muted-foreground hover:text-primary transition-colors py-1 cursor-pointer"
                onClick={() => {
                  setShowVerification(false);
                  setVerificationCode("");
                  setActiveTab("login");
                }}
              >
                Already verified? Return to sign in
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const fieldLabel = "text-xs sm:text-sm font-bold text-foreground";
  const fieldInput =
    "auth-input h-10 sm:h-11 rounded-2xl border-border/70 bg-background px-3.5 sm:px-4 text-sm sm:text-base glass-card";

  return (
    <div className={cn(shellClass, "px-4 sm:px-6")}>
      <div
        className="floating-blob w-96 h-96 bg-primary/20 top-0 left-0"
        style={{ animationDelay: "0s" }}
      />
      <div
        className="floating-blob w-80 h-80 bg-secondary/20 top-1/3 right-0"
        style={{ animationDelay: "-5s" }}
      />
      <div className="w-full max-w-[94%] sm:max-w-md">
        <div className="flex justify-start">
          <BackLink />
        </div>
        <div className="glass-card rounded-[2rem] p-4 sm:p-6 sm:py-5 premium-shadow-lg">
          <Brand />

          <h2 className="mt-2 text-center text-lg sm:text-xl font-black tracking-tight text-foreground uppercase">
            {showReset ? "Reset password" : activeTab === "login" ? "Welcome" : "Create account"}
          </h2>
          <p className="mx-auto mt-0.5 max-w-xs text-center text-xs sm:text-sm leading-snug text-muted-foreground">
            {showReset
              ? "Enter your email or username and we'll send you a reset link."
              : activeTab === "login"
                ? "Sign in to track your points and rewards."
                : "Join Noble Gain and start earning points from simple tasks."}
          </p>

          {!showReset && (
            <>
              <Button
                variant="outline"
                onClick={handleGoogleLogin}
                className="mt-3.5 sm:mt-4 h-10 sm:h-11 w-full rounded-2xl border-border/70 bg-background text-xs sm:text-sm font-bold glass-card hover:bg-primary/5 transition-colors"
              >
                <img
                  src="https://www.google.com/favicon.ico"
                  className="mr-2.5 h-3.5 w-3.5"
                  alt=""
                />
                Continue with Google
              </Button>

              <div className="relative my-2.5 sm:my-3.5">
                <div className="absolute inset-0 flex items-center">
                  <span className="w-full border-t border-border/70" />
                </div>
                <div className="relative flex justify-center">
                  <span className="bg-card px-2.5 text-[10px] sm:text-xs text-muted-foreground uppercase tracking-wider font-bold">
                    or email
                  </span>
                </div>
              </div>
            </>
          )}

          {error && (
            <div className="mb-3 rounded-2xl bg-destructive/10 p-2.5 text-sm font-bold text-destructive">
              {error}
            </div>
          )}

          {showReset ? (
            <form onSubmit={handlePasswordReset} className="space-y-3 sm:space-y-3.5">
              <div className="space-y-1 sm:space-y-1.5">
                <Label htmlFor="reset-email" className={fieldLabel}>
                  Email or username
                </Label>
                <Input
                  id="reset-email"
                  type="text"
                  autoCapitalize="none"
                  autoCorrect="off"
                  className={fieldInput}
                  value={resetEmail}
                  onChange={(e) => setResetEmail(e.target.value)}
                  required
                />
              </div>
              <div className="pt-1">
                <Button
                  type="submit"
                  className="h-10 sm:h-11 w-full rounded-2xl text-sm sm:text-base font-bold premium-shadow hover:scale-105 transition-transform"
                  disabled={resetLoading}
                >
                  {resetLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  {resetSent ? "Resend link" : "Send reset link"}
                </Button>
              </div>
              <button
                type="button"
                className="w-full text-center text-xs sm:text-sm font-bold text-muted-foreground hover:text-primary transition-colors"
                onClick={() => {
                  setShowReset(false);
                  setError("");
                }}
              >
                Back to sign in
              </button>
            </form>
          ) : (
            <div className="mt-2.5 sm:mt-3.5 w-full">
              {activeTab === "login" ? (
                <div className="space-y-3 sm:space-y-3.5">
                  <form onSubmit={handleEmailLogin} className="space-y-3 sm:space-y-3.5">
                    <div className="space-y-1 sm:space-y-1.5">
                      <Label htmlFor="identifier" className={fieldLabel}>
                        Email or username
                      </Label>
                      <Input
                        id="identifier"
                        className={fieldInput}
                        autoCapitalize="none"
                        placeholder="Enter email or username"
                        value={identifier}
                        onChange={(e) => setIdentifier(e.target.value)}
                        required
                      />
                    </div>
                    <div className="space-y-1 sm:space-y-1.5">
                      <Label htmlFor="password" className={fieldLabel}>
                        Password
                      </Label>
                      <div className="relative">
                        <Input
                          id="password"
                          type={showPassword ? "text" : "password"}
                          className={cn(fieldInput, "pr-12")}
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          required
                        />
                        <button
                          type="button"
                          onClick={() => setShowPassword(!showPassword)}
                          className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground transition-colors hover:text-primary"
                          aria-label={showPassword ? "Hide password" : "Show password"}
                        >
                          {showPassword ? (
                            <EyeOff className="h-4 w-4" />
                          ) : (
                            <Eye className="h-4 w-4" />
                          )}
                        </button>
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-0.5">
                      <div className="flex items-center gap-1.5 sm:gap-2">
                        <Checkbox
                          id="rememberMe"
                          checked={rememberMe}
                          onCheckedChange={(checked) => setRememberMe(checked === true)}
                        />
                        <Label
                          htmlFor="rememberMe"
                          className="cursor-pointer text-xs sm:text-sm font-medium text-muted-foreground"
                        >
                          Remember me
                        </Label>
                      </div>
                      <button
                        type="button"
                        className="text-xs sm:text-sm font-semibold text-primary hover:underline"
                        onClick={() => {
                          setShowReset(true);
                          setResetEmail(identifier.trim());
                          setError("");
                        }}
                      >
                        Forgot password?
                      </button>
                    </div>

                    <div className="pt-1">
                      <Button
                        type="submit"
                        className="h-10 sm:h-11 w-full rounded-2xl text-sm sm:text-base font-bold premium-shadow hover:scale-105 transition-transform"
                        disabled={loading}
                      >
                        {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                        Sign in
                      </Button>
                    </div>
                  </form>
                  <p className="text-center text-xs sm:text-sm font-bold text-muted-foreground pt-0.5">
                    Don't have an account?{" "}
                    <button
                      type="button"
                      className="font-bold text-primary hover:underline transition-colors"
                      onClick={() => setActiveTab("signup")}
                    >
                      Sign up
                    </button>
                  </p>
                </div>
              ) : (
                <div className="space-y-3 sm:space-y-3.5">
                  <form onSubmit={handleEmailSignUp} className="space-y-3 sm:space-y-3.5">
                    <div className="space-y-1 sm:space-y-1.5">
                      <Label htmlFor="full-name" className={fieldLabel}>
                        Full name
                      </Label>
                      <Input
                        id="full-name"
                        className={fieldInput}
                        value={fullName}
                        onChange={(e) => setFullName(e.target.value)}
                        required
                      />
                    </div>
                    <div className="space-y-1 sm:space-y-1.5">
                      <Label htmlFor="signup-username" className={fieldLabel}>
                        Username
                      </Label>
                      <div className="relative">
                        <Input
                          id="signup-username"
                          className={cn(
                            fieldInput,
                            "pr-12",
                            usernameStatus.available === true && "border-green-500/60",
                            usernameStatus.available === false && "border-destructive/60",
                            usernameStatus.loading && "border-primary/60",
                          )}
                          value={username}
                          onChange={(e) => {
                            const nextValue = normalizeUsername(e.target.value);
                            setUsername(nextValue);

                            if (!nextValue) {
                              setUsernameStatus({
                                loading: false,
                                available: null,
                                error: false,
                                message: "",
                              });
                              return;
                            }

                            if (nextValue.length < 3 || !/^[a-z0-9_]+$/.test(nextValue)) {
                              setUsernameStatus({
                                loading: false,
                                available: false,
                                error: true,
                                message: getUsernameStatus(nextValue).message,
                              });
                              return;
                            }

                            debouncedUsernameCheck(nextValue);
                          }}
                          required
                        />
                        {usernameStatus.loading && (
                          <Loader2 className="absolute right-4 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-muted-foreground" />
                        )}
                        {usernameStatus.available === true && !usernameStatus.loading && (
                          <CheckCircle2 className="absolute right-4 top-1/2 h-4 w-4 -translate-y-1/2 text-green-500" />
                        )}
                        {usernameStatus.available === false && !usernameStatus.loading && (
                          <span className="absolute right-4 top-1/2 -translate-y-1/2 text-sm font-black text-destructive">
                            !
                          </span>
                        )}
                      </div>
                      {usernameStatus.message && (
                        <p
                          className={cn(
                            "text-xs font-semibold",
                            usernameStatus.error ? "text-destructive" : "text-green-600",
                          )}
                        >
                          {usernameStatus.error ? "✕ " : "✓ "}
                          {usernameStatus.message}
                        </p>
                      )}
                    </div>
                    <div className="space-y-1 sm:space-y-1.5">
                      <Label htmlFor="signup-email" className={fieldLabel}>
                        Email
                      </Label>
                      <Input
                        id="signup-email"
                        type="email"
                        className={fieldInput}
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                      />
                    </div>
                    <div className="space-y-1 sm:space-y-1.5">
                      <Label htmlFor="signup-password" className={fieldLabel}>
                        Password
                      </Label>
                      <div className="relative">
                        <Input
                          id="signup-password"
                          type={showSignupPassword ? "text" : "password"}
                          className={cn(fieldInput, "pr-12")}
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          required
                        />
                        <button
                          type="button"
                          onClick={() => setShowSignupPassword(!showSignupPassword)}
                          className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground transition-colors hover:text-primary"
                          aria-label={showSignupPassword ? "Hide password" : "Show password"}
                        >
                          {showSignupPassword ? (
                            <EyeOff className="h-4 w-4" />
                          ) : (
                            <Eye className="h-4 w-4" />
                          )}
                        </button>
                      </div>
                    </div>
                    <div className="space-y-1 sm:space-y-1.5">
                      <Label htmlFor="referral-code" className={fieldLabel}>
                        Referral code (optional)
                      </Label>
                      <div className="relative">
                        <Input
                          id="referral-code"
                          className={cn(
                            fieldInput,
                            "pr-12",
                            referralStatus.owner && "border-green-500/60",
                            referralStatus.error && "border-destructive/60",
                          )}
                          value={referralCode}
                          onChange={handleReferralChange}
                        />
                        {referralStatus.loading && (
                          <Loader2 className="absolute right-4 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-muted-foreground" />
                        )}
                        {referralStatus.owner && (
                          <CheckCircle2 className="absolute right-4 top-1/2 h-4 w-4 -translate-y-1/2 text-green-500" />
                        )}
                      </div>
                      {referralStatus.message && (
                        <p
                          id="referral-status-msg"
                          className={cn(
                            "text-xs font-semibold",
                            referralStatus.error ? "text-destructive" : "text-green-600",
                          )}
                        >
                          {referralStatus.error ? "✕ " : "✓ "}
                          {referralStatus.message}
                        </p>
                      )}
                    </div>

                    <div className="flex items-start gap-2 pt-1">
                      <Checkbox
                        id="terms"
                        checked={agreedToTerms}
                        onCheckedChange={(checked) => setAgreedToTerms(checked === true)}
                        className="mt-0.5"
                      />
                      <label
                        htmlFor="terms"
                        className="cursor-pointer text-xs font-medium text-muted-foreground"
                      >
                        I agree to the{" "}
                        <Link
                          to="/terms"
                          className="font-bold text-primary underline underline-offset-2"
                        >
                          Terms of Service
                        </Link>{" "}
                        and{" "}
                        <Link
                          to="/privacy"
                          className="font-bold text-primary underline underline-offset-2"
                        >
                          Privacy Policy
                        </Link>
                      </label>
                    </div>

                    <div className="pt-1">
                      <Button
                        type="submit"
                        className="h-10 sm:h-11 w-full rounded-2xl text-sm sm:text-base font-bold premium-shadow hover:scale-105 transition-transform"
                        disabled={loading || !agreedToTerms}
                      >
                        {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                        Create account
                      </Button>
                    </div>
                  </form>
                  <p className="text-center text-xs sm:text-sm font-bold text-muted-foreground pt-0.5">
                    Already have an account?{" "}
                    <button
                      type="button"
                      className="font-bold text-primary hover:underline transition-colors"
                      onClick={() => setActiveTab("login")}
                    >
                      Sign in
                    </button>
                  </p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
