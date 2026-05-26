/// <reference types="vite/client" />

interface DesktopBridge {
  getGitHubClientId: () => Promise<string>;
  openExternal: (url: string) => Promise<void>;
}

interface Window {
  desktop?: DesktopBridge;
}
