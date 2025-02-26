import NetworkExtension
import MMWormhole
import TFYSwiftSSRKit

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var wormhole: MMWormhole?
    private var vpnConfiguration: [String: Any]?
    private var ssManager: SSManager?
    private var isProxyRunning: Bool = false
    
    override init() {
        super.init()
        ssManager = SSManager.shared
        ssManager?.setup()
        ssManager?.logLevel = .debug
        setupWormhole()
    }
    
    private func setupWormhole() {
        NSLog("📱 初始化 Wormhole 通信")
        wormhole = MMWormhole(applicationGroupIdentifier: "group.com.vpn.ios.soms.somsDemo",
                             optionalDirectory: "vpn_tunnel")
        
        // 监听配置更新
        wormhole?.listenForMessage(withIdentifier: "vpn_config") { [weak self] message in
            NSLog("📥 收到新的 VPN 配置")
            if let config = message as? [String: Any] {
                self?.vpnConfiguration = config
                self?.applyConfiguration()
            }
        }
        
        // 监听流量统计请求
        wormhole?.listenForMessage(withIdentifier: "traffic_request") { [weak self] _ in
            NSLog("📊 收到流量统计请求")
            let upload = self?.ssManager?.uploadTraffic ?? 0
            let download = self?.ssManager?.downloadTraffic ?? 0
            let traffic = [
                "upload": upload,
                "download": download
            ] as [String : Any]
            self?.wormhole?.passMessageObject(traffic as NSDictionary, 
                                            identifier: "traffic_update")
        }
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("🚀 开始启动 VPN 隧道")
        
        // 1. 从 app group 获取 SS 配置
        guard let config = loadSSConfig() else {
            let error = NSError(domain: "group.com.tfyssr.tunnel",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "No SS configuration found"])
            NSLog("❌ 未找到 SS 配置")
            completionHandler(error)
            return
        }
        
        NSLog("📝 加载 SS 配置: \(config)")
        
        // 2. 配置网络设置
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: config.serverAddress)
        settings.mtu = NSNumber(value: 1500)
        
        // 3. 配置 IPv4
        let ipv4Settings = NEIPv4Settings(addresses: ["192.168.1.1"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings
        
        // 4. 配置 DNS
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        
        // 5. 应用网络设置
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("❌ 设置隧道网络失败: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            // 6. 启动 SS
            if let manager = self.ssManager {
                if manager.startProxy(withConfig: config.toDictionary()) {
                    NSLog("✅ SS 启动成功")
                    self.isProxyRunning = true
                    completionHandler(nil)
                } else {
                    NSLog("❌ SS 启动失败: \(manager.lastError)")
                    self.isProxyRunning = false
                    let error = NSError(domain: "com.tfyssr.tunnel",
                                      code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: manager.lastError])
                    completionHandler(error)
                }
            } else {
                let error = NSError(domain: "com.tfyssr.tunnel",
                                   code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "SS Manager not initialized"])
                NSLog("❌ SS Manager 未初始化")
                completionHandler(error)
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("🛑 停止 VPN 隧道, 原因: \(reason)")
        ssManager?.stop()
        isProxyRunning = false
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        NSLog("📬 收到应用消息: \(messageData.count) bytes")
        
        // 尝试解析消息
        if let message = String(data: messageData, encoding: .utf8) {
            NSLog("📨 消息内容: \(message)")
            
            // 处理特定命令
            switch message {
            case "get_status":
                let status = ["isProxyRunning": isProxyRunning]
                if let responseData = try? JSONSerialization.data(withJSONObject: status) {
                    completionHandler?(responseData)
                }
            case "refresh_config":
                applyConfiguration()
                completionHandler?(messageData)
            default:
                NSLog("⚠️ 未知命令: \(message)")
                completionHandler?(nil)
            }
        } else {
            NSLog("❌ 无法解析消息内容")
            completionHandler?(nil)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        NSLog("💤 VPN 进入休眠状态")
        completionHandler()
    }
    
    override func wake() {
        NSLog("⚡️ VPN 唤醒")
        if loadSSConfig() != nil {
            NSLog("🔄 重新应用配置")
            applyConfiguration()
        } else {
            NSLog("⚠️ 无可用配置")
        }
    }
    
    private func loadSSConfig() -> SSConfig? {
        NSLog("📥 正在加载 VPN 配置...")
        guard let config = vpnConfiguration else {
            NSLog("⚠️ VPN 配置为空")
            return nil
        }
        
        let ssConfig = SSConfig(serverAddress: config["server"] as? String ?? "",
                              serverPort: UInt16(config["server_port"] as? Int ?? 0),
                              password: config["password"] as? String ?? "",
                              method: config["method"] as? String ?? "",
                              timeout: config["timeout"] as? Int ?? 600)
        
        NSLog("✅ SS 配置加载成功: server=\(ssConfig.serverAddress), port=\(ssConfig.serverPort)")
        return ssConfig
    }
    
    private func applyConfiguration() {
        NSLog("🔄 正在应用新配置...")
        guard let config = loadSSConfig() else {
            NSLog("❌ 加载配置失败")
            return
        }
        
        if let manager = ssManager {
            let success = manager.startProxy(withConfig: config.toDictionary())
            if success {
                NSLog("✅ 配置应用成功")
                isProxyRunning = true
            } else {
                let errorMessage = manager.lastError
                NSLog("❌ 应用配置失败: \(errorMessage)")
                isProxyRunning = false
                wormhole?.passMessageObject(["error": errorMessage] as NSDictionary,
                                          identifier: "proxy_status")
            }
        } else {
            NSLog("❌ SS Manager 未初始化")
        }
    }
}
