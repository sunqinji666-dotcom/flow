const { spawn } = require('child_process')
const path = require('path')
const fs = require('fs')

class XrayManager {
  constructor() {
    this.process = null
  }

  getXrayPath() {
    const resourcePath = process.resourcesPath || path.join(__dirname, '..')
    const candidates = [
      path.join(resourcePath, 'xray-core', 'xray.exe'),
      path.join(resourcePath, 'xray-core', 'xray-windows-64.exe'),
      path.join(__dirname, '..', 'xray-core', 'xray.exe')
    ]
    for (const c of candidates) { if (fs.existsSync(c)) return c }
    return 'xray.exe'
  }

  async start(configJson) {
    await this.stop()
    const xrayPath = this.getXrayPath()
    const configDir = path.join(process.env.TEMP || '/tmp', 'flow-configs')
    fs.mkdirSync(configDir, { recursive: true })
    const configPath = path.join(configDir, 'config.json')
    fs.writeFileSync(configPath, configJson, 'utf8')

    const env = { ...process.env }
    env.XRAY_LOCATION_ASSET = path.dirname(xrayPath)
    env.V2RAY_LOCATION_ASSET = path.dirname(xrayPath)

    this.process = spawn(xrayPath, ['run', '-config', configPath], {
      cwd: path.dirname(xrayPath),
      env,
      stdio: 'ignore'
    })

    return new Promise((resolve) => {
      setTimeout(() => resolve(this.isRunning()), 1500)
    })
  }

  async stop() {
    if (this.process) {
      try { this.process.kill() } catch (_) {}
      this.process = null
    }
    return true
  }

  isRunning() {
    return this.process !== null && !this.process.killed
  }
}

module.exports = { XrayManager }
