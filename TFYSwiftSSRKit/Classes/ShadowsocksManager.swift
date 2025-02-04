import Foundation
import Network

/// 加密方法
public enum EncryptionMethod: String {
    // OpenSSL 支持的加密方法
    case aes128Gcm = "aes-128-gcm"
    case aes256Gcm = "aes-256-gcm"
    case aes128Cfb = "aes-128-cfb"
    case aes256Cfb = "aes-256-cfb"
    case chacha20 = "chacha20"
    case chacha20Poly1305 = "chacha20-poly1305"
    
    // libsodium 支持的加密方法
    case xchacha20 = "xchacha20"
    case xchacha20Poly1305 = "xchacha20-poly1305"
}

/// 路由策略
public enum RoutingStrategy {
    case direct              // 直连
    case proxy              // 代理
    case byLocation         // 根据地理位置选择
    case byLatency         // 根据延迟选择
    case loadBalance       // 负载均衡
}

/// Shadowsocks 配置结构
public struct ShadowsocksConfig {
    /// 服务器地址
    public let server: String
    /// 服务器端口
    public let serverPort: String
    /// 密码
    public let password: String
    /// 加密方法
    public let method: EncryptionMethod
    /// 本地监听地址
    public let localAddress: String
    /// 本地监听端口
    public let localPort: String
    /// 启用 UDP
    public let enableUDP: Bool
    /// 超时时间
    public let timeout: TimeInterval
    /// DNS 服务器
    public let dnsServer: String
    /// 代理模式
    public let mode: ProxyMode
    /// 路由策略
    public let routingStrategy: RoutingStrategy
    /// 启用 TLS
    public let enableTLS: Bool
    /// TLS 证书路径
    public let tlsCertPath: String?
    /// 启用地理位置优化
    public let enableGeoOptimization: Bool
    
    public init(
        server: String,
        serverPort: String,
        password: String,
        method: EncryptionMethod = .aes256Gcm,
        localAddress: String = "127.0.0.1",
        localPort: String = "1080",
        enableUDP: Bool = true,
        timeout: TimeInterval = 300,
        dnsServer: String = "8.8.8.8",
        mode: ProxyMode = .whitelist,
        routingStrategy: RoutingStrategy = .proxy,
        enableTLS: Bool = false,
        tlsCertPath: String? = nil,
        enableGeoOptimization: Bool = false
    ) {
        self.server = server
        self.serverPort = serverPort
        self.password = password
        self.method = method
        self.localAddress = localAddress
        self.localPort = localPort
        self.enableUDP = enableUDP
        self.timeout = timeout
        self.dnsServer = dnsServer
        self.mode = mode
        self.routingStrategy = routingStrategy
        self.enableTLS = enableTLS
        self.tlsCertPath = tlsCertPath
        self.enableGeoOptimization = enableGeoOptimization
    }
    
    /// 验证配置是否有效
    /// - Throws: 配置无效时抛出错误
    internal func validate() throws {
        if server.isEmpty {
            throw ShadowsocksError.invalidConfiguration("服务器地址不能为空")
        }
        if serverPort.isEmpty {
            throw ShadowsocksError.invalidConfiguration("服务器端口不能为空")
        }
        if let port = Int(serverPort), port < 1 || port > 65535 {
            throw ShadowsocksError.invalidConfiguration("服务器端口必须在 1-65535 之间")
        }
        if password.isEmpty {
            throw ShadowsocksError.invalidConfiguration("密码不能为空")
        }
        if method.isEmpty {
            throw ShadowsocksError.invalidConfiguration("加密方法不能为空")
        }
        if localAddress.isEmpty {
            throw ShadowsocksError.invalidConfiguration("本地监听地址不能为空")
        }
        if localPort.isEmpty {
            throw ShadowsocksError.invalidConfiguration("本地监听端口不能为空")
        }
        if let port = Int(localPort), port < 1 || port > 65535 {
            throw ShadowsocksError.invalidConfiguration("本地监听端口必须在 1-65535 之间")
        }
        if timeout < 0 {
            throw ShadowsocksError.invalidConfiguration("超时时间不能为负数")
        }
        if dnsServer.isEmpty {
            throw ShadowsocksError.invalidConfiguration("DNS 服务器不能为空")
        }
        
        // TLS 相关验证
        if enableTLS {
            if let certPath = tlsCertPath {
                if !FileManager.default.fileExists(atPath: certPath) {
                    throw ShadowsocksError.invalidConfiguration("TLS 证书文件不存在")
                }
            } else {
                throw ShadowsocksError.invalidConfiguration("启用 TLS 时必须提供证书路径")
            }
        }
    }
}

/// Shadowsocks 管理器
public class ShadowsocksManager {
    /// 单例
    public static let shared = ShadowsocksManager()
    
    /// 当前进程
    private var currentProcess: Process?
    
    /// 当前配置
    public internal(set) var currentConfig: ShadowsocksConfig?
    
    /// 二进制文件路径
    private let binaryPath: String
    
    /// 日志委托
    public weak var logDelegate: ShadowsocksLogDelegate?
    
    /// 网络监控
    private let networkMonitor = NetworkMonitor.shared
    
    /// 规则管理器
    private let ruleManager = RuleManager.shared
    
    /// GeoIP 数据库
    private var geoipDB: UnsafeMutablePointer<MMDB_s>?
    
    /// 初始化
    private init() {
        let bundle = Bundle(for: ShadowsocksManager.self)
        let installPath = bundle.path(forResource: "shadowsocks/install/bin/sslocal", ofType: nil) ?? ""
        binaryPath = installPath
        
        // 设置网络监控委托
        networkMonitor.delegate = self
        
        // 初始化 GeoIP 数据库
        initGeoIPDB()
        
        // 初始化 OpenSSL
        initOpenSSL()
        
        // 初始化 libsodium
        initLibsodium()
    }
    
    /// 初始化 GeoIP 数据库
    private func initGeoIPDB() {
        let bundle = Bundle(for: ShadowsocksManager.self)
        if let dbPath = bundle.path(forResource: "GeoLite2-Country", ofType: "mmdb", inDirectory: "Resources") {
            var db = MMDB_s()
            let status = MMDB_open(dbPath, MMDB_MODE_MMAP, &db)
            if status == MMDB_SUCCESS {
                geoipDB = UnsafeMutablePointer<MMDB_s>.allocate(capacity: 1)
                geoipDB?.pointee = db
                logDelegate?.shadowsocks(self, didReceiveLog: .info, message: "GeoIP database loaded successfully")
            } else {
                logDelegate?.shadowsocks(self, didReceiveLog: .error, message: "Failed to open GeoIP database: \(String(cString: MMDB_strerror(status)))")
            }
        } else {
            logDelegate?.shadowsocks(self, didReceiveLog: .error, message: "GeoIP database file not found in Resources")
        }
    }
    
    /// 初始化 OpenSSL
    private func initOpenSSL() {
        SSL_library_init()
        SSL_load_error_strings()
        OpenSSL_add_all_algorithms()
    }
    
    /// 初始化 libsodium
    private func initLibsodium() {
        if sodium_init() < 0 {
            logDelegate?.shadowsocks(self, didReceiveLog: .error, message: "Failed to initialize libsodium")
        }
    }
    
    /// 获取 IP 地理位置信息
    private func getIPLocation(_ ip: String) -> String? {
        guard let db = geoipDB else { return nil }
        
        var gai = addrinfo()
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(ip, nil, &gai, &result) == 0 else { return nil }
        defer { freeaddrinfo(result) }
        
        var mmdb_result = MMDB_lookup_result_s()
        var error: Int32 = 0
        
        MMDB_lookup_sockaddr(db, result?.pointee.ai_addr, &mmdb_result, &error)
        
        if error != MMDB_SUCCESS { return nil }
        
        var entry_data = MMDB_entry_data_s()
        error = MMDB_get_value(&mmdb_result.entry, &entry_data, "country", "iso_code", nil)
        
        if error != MMDB_SUCCESS { return nil }
        
        if entry_data.has_data {
            return String(cString: entry_data.utf8_string)
        }
        
        return nil
    }
    
    /// 启动 Shadowsocks
    /// - Parameter config: Shadowsocks 配置
    /// - Throws: 启动失败时抛出错误
    public func start(with config: ShadowsocksConfig) throws {
        // 验证配置
        try config.validate()
        
        // 检查二进制文件
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw ShadowsocksError.binaryNotFound
        }
        
        // 检查是否已在运行
        if isRunning {
            throw ShadowsocksError.processAlreadyRunning
        }
        
        // 停止现有进程
        stop()
        
        // 保存当前配置
        currentConfig = config
        
        // 创建新进程
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        
        // 设置参数
        var arguments = [
            "-s", config.server,
            "-p", config.serverPort,
            "-k", config.password,
            "-m", config.method.rawValue,
            "-b", config.localAddress,
            "-l", config.localPort,
            "--log-without-time"
        ]
        
        // 添加可选参数
        if config.enableUDP {
            arguments.append("--enable-udp")
        }
        
        arguments.append(contentsOf: ["--timeout", String(Int(config.timeout))])
        arguments.append(contentsOf: ["--dns", config.dnsServer])
        
        // 添加 TLS 支持
        if config.enableTLS {
            arguments.append("--tls")
            if let certPath = config.tlsCertPath {
                arguments.append(contentsOf: ["--tls-cert", certPath])
            }
        }
        
        // 添加地理位置优化
        if config.enableGeoOptimization {
            if let location = getIPLocation(config.server) {
                logDelegate?.shadowsocks(self, didReceiveLog: .info, message: "Server location: \(location)")
            }
        }
        
        process.arguments = arguments
        
        // 设置输出管道
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // 设置输出处理
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    // 处理每一行日志
                    output.split(separator: "\n").forEach { line in
                        let logLine = String(line)
                        if let (level, message) = self.parseLogLine(logLine) {
                            self.logDelegate?.shadowsocks(self, didReceiveLog: level, message: message)
                            
                            // 解析流量统计
                            if message.contains("statistics:") {
                                self.parseTrafficStatistics(message)
                            }
                        }
                    }
                }
            }
        }
        
        // 启动进程
        do {
            try process.run()
            currentProcess = process
            
            // 通知代理状态变化
            networkMonitor.delegate?.proxyStatusDidChange(.connected)
        } catch {
            throw ShadowsocksError.startFailed(error.localizedDescription)
        }
        
        // 监听进程退出
        process.terminationHandler = { [weak self] process in
            guard let self = self else { return }
            let status = process.terminationStatus
            let message = "Process terminated with status: \(status)"
            self.logDelegate?.shadowsocks(self, didReceiveLog: .info, message: message)
            
            // 通知代理状态变化
            self.networkMonitor.delegate?.proxyStatusDidChange(.disconnected)
            
            if process == self.currentProcess {
                self.currentProcess = nil
                self.currentConfig = nil
            }
        }
    }
    
    /// 停止 Shadowsocks
    public func stop() {
        guard let process = currentProcess else { return }
        process.terminate()
        currentProcess = nil
        currentConfig = nil
        
        // 通知代理状态变化
        networkMonitor.delegate?.proxyStatusDidChange(.disconnected)
    }
    
    /// 检查是否正在运行
    public var isRunning: Bool {
        guard let process = currentProcess else { return false }
        return process.isRunning
    }
    
    /// 解析流量统计
    private func parseTrafficStatistics(_ message: String) {
        // 示例日志格式: "statistics: upload=1234 download=5678"
        let components = message.components(separatedBy: " ")
        var upload: UInt64 = 0
        var download: UInt64 = 0
        
        for component in components {
            if component.hasPrefix("upload="),
               let value = UInt64(component.dropFirst("upload=".count)) {
                upload = value
            } else if component.hasPrefix("download="),
                      let value = UInt64(component.dropFirst("download=".count)) {
                download = value
            }
        }
        
        // 更新流量统计
        networkMonitor.updateStatistics(upload: upload, download: download)
    }
    
    /// 析构函数
    deinit {
        stop()
        
        // 清理 GeoIP 数据库
        if let db = geoipDB {
            MMDB_close(db.pointee)
            db.deallocate()
        }
        
        // 清理 OpenSSL
        EVP_cleanup()
        CRYPTO_cleanup_all_ex_data()
        ERR_free_strings()
        
        // libsodium 不需要清理
    }
}

// MARK: - NetworkMonitorDelegate

extension ShadowsocksManager: NetworkMonitorDelegate {
    public func networkStatusDidChange(_ status: NetworkStatus) {
        // 网络状态变化时的处理
        switch status {
        case .unavailable:
            // 网络不可用时停止代理
            stop()
        case .wifi, .cellular, .ethernet:
            // 网络恢复时，如果配置了自动重连则重新启动代理
            if networkMonitor.autoReconnect,
               let config = currentConfig {
                try? start(with: config)
            }
        case .unknown:
            break
        }
    }
    
    public func proxyStatusDidChange(_ status: ProxyStatus) {
        // 代理状态变化时通知委托
        switch status {
        case .connected:
            logDelegate?.shadowsocks(self, didReceiveLog: .info, message: "Proxy connected")
        case .disconnected:
            logDelegate?.shadowsocks(self, didReceiveLog: .info, message: "Proxy disconnected")
        case .connecting:
            logDelegate?.shadowsocks(self, didReceiveLog: .info, message: "Proxy connecting")
        case .error(let error):
            logDelegate?.shadowsocks(self, didReceiveLog: .error, message: "Proxy error: \(error.localizedDescription)")
        }
    }
} 