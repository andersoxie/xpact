import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// In development the API runs on http://localhost:5080 (website/scripts/dev.ps1);
// Vite forwards /api there, so the browser only ever talks to one origin.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { "/api": "http://localhost:5080" },
  },
  build: {
    // scripts/publish.ps1 copies this folder into the API's wwwroot.
    outDir: "dist",
    emptyOutDir: true,
  },
});
