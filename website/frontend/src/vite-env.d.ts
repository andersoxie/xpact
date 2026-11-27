/// <reference types="vite/client" />

// Set by website/scripts/version-env.ps1 (VERSION file + short git hash) before the build.
interface ImportMetaEnv {
  readonly VITE_XPACT_VERSION?: string;
  readonly VITE_XPACT_COMMIT?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
