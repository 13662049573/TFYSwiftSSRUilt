import NetworkExtension
import TFYSwiftSSRKit

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var tunnelProvider: TFYPacketTunnelProvider?
    private var config: TFYConfig?
    private var lastTrafficUpload: UInt64 = 0
    private var lastTrafficDownload: UInt64 = 0
    private var trafficTimer: Timer?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let options = options, let configDict = options["config"] as? [String: Any] else {
            completionHandler(NSError(domain: "com.tfyswiftssr.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing configuration"]))
            return
        }
        
        // 创建配置
        guard let config = TFYConfig(json: configDict) else {
            completionHandler(NSError(domain: "com.tfyswiftssr.error", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid configuration"]))
            return
        }
        
        self.config = config
        self.tunnelProvider = TFYPacketTunnelProvider()
        
        // 启动隧道
        self.tunnelProvider?.startTunnel(with: config, completionHandler: { error in
            if let error = error {
                NSLog("Failed to start tunnel: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            // 设置网络设置
            let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: config.server ?? "127.0.0.1")
            
            // 配置 DNS
            let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
            dnsSettings.matchDomains = [""]
            networkSettings.dnsSettings = dnsSettings
            
            // 配置 IPv4 路由
            let ipv4Settings = NEIPv4Settings(addresses: ["192.168.1.1"], subnetMasks: ["255.255.255.0"])
            let defaultRoute = NEIPv4Route.default()
            ipv4Settings.includedRoutes = [defaultRoute]
            networkSettings.ipv4Settings = ipv4Settings
            
            // 应用网络设置
            self.setTunnelNetworkSettings(networkSettings) { error in
                if let error = error {
                    NSLog("Failed to set network settings: \(error.localizedDescription)")
                    completionHandler(error)
                    return
                }
                
                // 启动流量统计定时器
                self.startTrafficTimer()
                
                completionHandler(nil)
            }
        })
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // 停止流量统计定时器
        stopTrafficTimer()
        
        // 停止隧道
        tunnelProvider?.stopTunnel(with: reason, completionHandler: {
            completionHandler()
        })
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = try? JSONSerialization.jsonObject(with: messageData, options: []) as? [String: Any],
              let type = message["type"] as? String else {
            completionHandler?(nil)
            return
        }
        
        switch type {
        case "getTraffic":
            // 获取流量统计
            var upload: UInt64 = 0
            var download: UInt64 = 0
            tunnelProvider?.getTraffic(withUpload: &upload, download: &download)
            
            let response: [String: UInt64] = [
                "upload": upload,
                "download": download
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response, options: []) {
                completionHandler?(responseData)
            } else {
                completionHandler?(nil)
            }
            
        case "updateConfig":
            // 更新配置
            if let configDict = message["config"] as? [String: Any],
               let newConfig = TFYConfig(json: configDict) {
                self.config = newConfig
                
                // 使用新添加的方法更新配置
                tunnelProvider?.update(config: newConfig) { error in
                    var response: [String: Any] = [:]
                    
                    if let error = error {
                        response["status"] = "failed"
                        response["error"] = error.localizedDescription
                    } else {
                        response["status"] = "success"
                    }
                    
                    if let responseData = try? JSONSerialization.data(withJSONObject: response, options: []) {
                        completionHandler?(responseData)
                    } else {
                        completionHandler?(nil)
                    }
                }
            } else {
                completionHandler?(nil)
            }
            
        case "resetTraffic":
            // 重置流量统计
            tunnelProvider?.resetTrafficStats()
            lastTrafficUpload = 0
            lastTrafficDownload = 0
            
            let response: [String: String] = ["status": "success"]
            if let responseData = try? JSONSerialization.data(withJSONObject: response, options: []) {
                completionHandler?(responseData)
            } else {
                completionHandler?(nil)
            }
            
        case "checkStatus":
            // 检查隧道状态
            let isActive = tunnelProvider?.isTunnelActive() ?? false
            
            let response: [String: Any] = [
                "status": isActive ? "active" : "inactive",
                "config": config?.toJSON() ?? [:]
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response, options: []) {
                completionHandler?(responseData)
            } else {
                completionHandler?(nil)
            }
            
        default:
            completionHandler?(nil)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // 暂停流量统计
        stopTrafficTimer()
        completionHandler()
    }
    
    override func wake() {
        // 恢复流量统计
        startTrafficTimer()
    }
    
    // MARK: - Private Methods
    
    private func startTrafficTimer() {
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTrafficStatistics()
        }
    }
    
    private func stopTrafficTimer() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }
    
    private func updateTrafficStatistics() {
        var upload: UInt64 = 0
        var download: UInt64 = 0
        tunnelProvider?.getTraffic(withUpload: &upload, download: &download)
        
        // 计算增量
        let uploadDelta = upload - lastTrafficUpload
        let downloadDelta = download - lastTrafficDownload
        
        // 更新上次值
        lastTrafficUpload = upload
        lastTrafficDownload = download
        
        // 如果有显著变化，记录流量变化
        if uploadDelta > 1024 || downloadDelta > 1024 {
            NSLog("Traffic update - Upload: \(formatTraffic(upload)), Download: \(formatTraffic(download))")
            
            // 注意：NEPacketTunnelProvider 不能主动发送消息到应用
            // 应用需要通过 handleAppMessage 方法请求流量统计
            // 这里只记录日志，不尝试发送消息
        }
    }
    
    private func formatTraffic(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }
}
