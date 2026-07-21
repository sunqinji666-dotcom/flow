const https = require('https')
const { XrayManager } = require('./xray-manager')

class NodeService {
  constructor() {
    this.remoteUrl = process.env.FLOW_REMOTE_NODES_URL || 'https://your-server.example/flow/nodes.json'
    this.xray = null
  }

  setXray(xray) { this.xray = xray }

  async loadNodes() {
    const raw = await this.fetchNodes()
    if (!raw || raw.length === 0) return []

    const validated = await this.validateNodes(raw)
    return validated
  }

  async fetchNodes() {
    return new Promise((resolve) => {
      https.get(this.remoteUrl, { timeout: 10000 }, (res) => {
        let body = ''
        res.on('data', d => body += d)
        res.on('end', () => {
          try {
            const json = JSON.parse(body)
            const nodes = json.nodes || json
            resolve(Array.isArray(nodes) ? nodes : [])
          } catch (e) {
            resolve([])
          }
        })
        res.on('error', () => resolve([]))
      }).on('error', () => resolve([])).on('timeout', () => resolve([]))
    })
  }

  async validateNodes(candidates) {
    if (!this.xray) return candidates

    const passed = []
    for (let i = 0; i < candidates.length; i++) {
      const node = candidates[i]
      const testPort = 20080 + passed.length
      const testConfig = this.buildValidationConfig(node, testPort)

      const started = await this.xray.start(testConfig)
      if (!started) { await this.xray.stop(); continue }

      await this.sleep(1500)
      const latency = await this.testSocksProxy(testPort)
      await this.xray.stop()

      if (latency !== null) {
        node.latency = latency
        passed.push(node)
      }
    }
    return passed
  }

  buildValidationConfig(node, socksPort) {
    return JSON.stringify({
      log: { loglevel: 'error' },
      inbounds: [{ tag: 'socks-in', port: socksPort, listen: '127.0.0.1', protocol: 'socks', settings: { udp: true } }],
      outbounds: [
        {
          tag: 'proxy', protocol: node.protocolType || 'vless',
          settings: { vnext: [{ address: node.host, port: node.port, users: [{ id: node.uuid, encryption: 'none', flow: node.flow || '' }] }] },
          streamSettings: {
            network: node.transport || 'tcp', security: node.security || 'reality',
            realitySettings: { serverName: node.sni, fingerprint: node.fingerprint, publicKey: node.publicKey || '', shortId: node.shortId || '' }
          }
        },
        { tag: 'direct', protocol: 'freedom' }
      ],
      routing: { domainStrategy: 'AsIs', rules: [{ type: 'field', inboundTag: ['socks-in'], outboundTag: 'proxy' }] }
    })
  }

  async testSocksProxy(socksPort) {
    const testUrls = ['https://www.google.com/generate_204', 'https://www.gstatic.com/generate_204', 'https://www.cloudflare.com/cdn-cgi/trace']
    for (const url of testUrls) {
      try {
        const start = Date.now()
        const { SocksProxyAgent } = require('socks-proxy-agent')
        const agent = new SocksProxyAgent(`socks5://127.0.0.1:${socksPort}`)
        const resp = await fetch(url, { agent, signal: AbortSignal.timeout(6000) })
        if (resp.status === 200 || resp.status === 204) return Date.now() - start
      } catch (_) { continue }
    }
    return null
  }

  sleep(ms) { return new Promise(r => setTimeout(r, ms)) }
}

module.exports = { NodeService }
