const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("desktop", {
  getGitHubClientId: () => ipcRenderer.invoke("app:get-github-client-id"),
  openExternal: (url) => ipcRenderer.invoke("app:open-external", url)
});
