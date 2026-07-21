const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('flowAPI', {
  start: (config) => ipcRenderer.invoke('xray-start', config),
  stop: () => ipcRenderer.invoke('xray-stop'),
  status: () => ipcRenderer.invoke('xray-status'),
  refreshNodes: () => ipcRenderer.invoke('nodes-refresh'),
  onNodesLoaded: (cb) => ipcRenderer.on('nodes-loaded', (_, nodes) => cb(nodes)),
  onNodesStatus: (cb) => ipcRenderer.on('nodes-status', (_, msg) => cb(msg))
})
