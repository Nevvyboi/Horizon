/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_DATA_SOURCE?: string;
}
interface ImportMeta {
  readonly env: ImportMetaEnv;
}
