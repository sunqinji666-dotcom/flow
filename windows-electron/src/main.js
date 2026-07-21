const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain } = require('electron')
const path = require('path')
const { XrayManager } = require('./xray-manager')
const { NodeService } = require('./node-service')

let mainWindow = null
let tray = null
let xray = null
let nodeService = null

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 380, height: 700, resizable: false, frame: false, transparent: true,
    backgroundColor: '#00000000',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false }
  })
  mainWindow.loadFile(path.join(__dirname, 'index.html'))
  mainWindow.center()
  mainWindow.on('close', (e) => { if (!app.isQuitting) { e.preventDefault(); mainWindow.hide() } })
}

function createTray() {
  tray = new Tray(nativeImage.createEmpty())
  const menu = Menu.buildFromTemplate([
    { label: '显示主界面', click: () => { if (mainWindow) { mainWindow.show(); mainWindow.center() } } },
    { type: 'separator' },
    { label: '退出 Flow', click: () => { app.isQuitting = true; app.quit() } }
  ])
  tray.setToolTip('Flow')
  tray.setContextMenu(menu)
  tray.on('click', () => { if (mainWindow) { mainWindow.show(); mainWindow.center() } })
}

app.whenReady().then(async () => {
  xray = new XrayManager()
  nodeService = new NodeService()
  nodeService.setXray(xray)

  createWindow()
  createTray()

  // Load and validate nodes at startup
  mainWindow.webContents.send('nodes-status', '正在拉取节点…')
  const nodes = await nodeService.loadNodes()
  if (nodes.length > 0) {
    mainWindow.webContents.send('nodes-loaded', nodes)
  } else {
    mainWindow.webContents.send('nodes-status', '无可用节点')
  }

  ipcMain.handle('xray-start', async (e, config) => xray.start(config))
  ipcMain.handle('xray-stop', async () => xray.stop())
  ipcMain.handle('xray-status', async () => xray.isRunning())
  ipcMain.handle('nodes-refresh', async () => {
    mainWindow.webContents.send('nodes-status', '正在检测节点…')
    const nodes = await nodeService.loadNodes()
    if (nodes.length > 0) mainWindow.webContents.send('nodes-loaded', nodes)
    else mainWindow.webContents.send('nodes-status', '无可用节点')
    return nodes
  })

  app.on('activate', () => { if (mainWindow) mainWindow.show() })
})

app.on('window-all-closed', () => {})
app.on('before-quit', () => { app.isQuitting = true; if (xray) xray.stop() })
