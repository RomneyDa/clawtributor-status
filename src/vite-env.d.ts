/// <reference types="vite/client" />

declare module "*.graphql?raw" {
  const content: string;
  export default content;
}

interface DesktopBridge {
  getGitHubClientId: () => Promise<string>;
  openExternal: (url: string) => Promise<void>;
}

interface Window {
  desktop?: DesktopBridge;
}
