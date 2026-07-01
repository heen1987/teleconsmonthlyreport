import { defineConfig } from "vite";

export default defineConfig({
  base: process.env.VITE_BASE_PATH ?? "/",
  publicDir: process.env.VITE_DISABLE_PUBLIC_COPY === "1" ? false : "public",
  build: {
    outDir: process.env.VITE_OUT_DIR ?? "dist",
  },
});
