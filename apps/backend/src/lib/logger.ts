import { config } from "../config/env";

const isDevelopment = config.nodeEnv === "development";

export const logger = {
  info: (...args: unknown[]) => {
    if (isDevelopment) {
      console.log(...args);
    }
  },
  error: (...args: unknown[]) => {
    // Error logları her zaman gösterilir (production'da da)
    console.error(...args);
  },
  warn: (...args: unknown[]) => {
    // Warn logları production'da da gösterilir (önemli uyarılar için)
    console.warn(...args);
  },
  debug: (...args: unknown[]) => {
    // Debug logları sadece development'ta
    if (isDevelopment) {
      console.log(...args);
    }
  },
};

