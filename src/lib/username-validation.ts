export type UsernameStatus = {
  isValid: boolean;
  state: "idle" | "loading" | "success" | "error";
  message: string;
};

export function normalizeUsername(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9_]/g, "");
}

export function getUsernameStatus(username: string, available: boolean | null = null): UsernameStatus {
  const normalized = normalizeUsername(username);

  if (!username.trim()) {
    return { isValid: false, state: "idle", message: "Choose a username to continue." };
  }

  if (normalized.length < 3) {
    return {
      isValid: false,
      state: "error",
      message: "Username must be at least 3 characters long.",
    };
  }

  if (normalized !== username.trim().toLowerCase()) {
    return {
      isValid: false,
      state: "error",
      message: "Use only letters, numbers, and underscores.",
    };
  }

  if (normalized.length > 20) {
    return {
      isValid: false,
      state: "error",
      message: "Username cannot exceed 20 characters.",
    };
  }

  if (available === true) {
    return {
      isValid: true,
      state: "success",
      message: "Username available.",
    };
  }

  if (available === false) {
    return {
      isValid: false,
      state: "error",
      message: "Username is already taken.",
    };
  }

  return {
    isValid: true,
    state: "success",
    message: "Username available.",
  };
}

export type UsernameFieldState = {
  loading: boolean;
  available: boolean | null;
  message: string;
  error: boolean;
};

export function toUsernameFieldState(status: UsernameStatus): UsernameFieldState {
  return {
    loading: status.state === "loading",
    available: status.state === "success" ? true : status.state === "error" ? false : null,
    message: status.message,
    error: status.state === "error",
  };
}
