import Foundation

/// 配置管理器
public class ConfigurationManager {
    /// 单例
    public static let shared = ConfigurationManager()
    
    /// 配置文件 URL
    private let configFileURL: URL
    
    /// 所有配置
    public private(set) var configurations: [String: ShadowsocksConfig] = [:]
    
    /// 当前选中的配置名称
    public private(set) var selectedConfigName: String?
    
    /// 初始化
    private init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        configFileURL = documentsURL.appendingPathComponent("shadowsocks_configs.json")
        loadConfigurations()
    }
    
    /// 加载配置
    private func loadConfigurations() {
        guard let data = try? Data(contentsOf: configFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let configs = json["configs"] as? [String: [String: Any]],
              let selected = json["selected"] as? String? else {
            return
        }
        
        configurations = configs.compactMapValues { dict in
            guard let server = dict["server"] as? String,
                  let serverPort = dict["serverPort"] as? String,
                  let password = dict["password"] as? String else {
                return nil
            }
            
            return ShadowsocksConfig(
                server: server,
                serverPort: serverPort,
                password: password,
                method: dict["method"] as? String ?? "aes-256-gcm",
                localAddress: dict["localAddress"] as? String ?? "127.0.0.1",
                localPort: dict["localPort"] as? String ?? "1080",
                enableUDP: dict["enableUDP"] as? Bool ?? true,
                timeout: dict["timeout"] as? TimeInterval ?? 300,
                dnsServer: dict["dnsServer"] as? String ?? "8.8.8.8",
                mode: ProxyMode(rawValue: dict["mode"] as? String ?? "") ?? .whitelist
            )
        }
        
        selectedConfigName = selected
    }
    
    /// 保存配置
    private func saveConfigurations() {
        let configs = configurations.mapValues { config -> [String: Any] in
            [
                "server": config.server,
                "serverPort": config.serverPort,
                "password": config.password,
                "method": config.method,
                "localAddress": config.localAddress,
                "localPort": config.localPort,
                "enableUDP": config.enableUDP,
                "timeout": config.timeout,
                "dnsServer": config.dnsServer,
                "mode": String(describing: config.mode)
            ]
        }
        
        let json: [String: Any] = [
            "configs": configs,
            "selected": selectedConfigName as Any
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? data.write(to: configFileURL)
        }
    }
    
    /// 添加配置
    /// - Parameters:
    ///   - config: 配置
    ///   - name: 配置名称
    public func addConfiguration(_ config: ShadowsocksConfig, name: String) {
        configurations[name] = config
        saveConfigurations()
    }
    
    /// 删除配置
    /// - Parameter name: 配置名称
    public func removeConfiguration(name: String) {
        configurations.removeValue(forKey: name)
        if selectedConfigName == name {
            selectedConfigName = nil
        }
        saveConfigurations()
    }
    
    /// 选择配置
    /// - Parameter name: 配置名称
    /// - Returns: 选中的配置
    @discardableResult
    public func selectConfiguration(name: String) -> ShadowsocksConfig? {
        guard let config = configurations[name] else {
            return nil
        }
        selectedConfigName = name
        saveConfigurations()
        return config
    }
    
    /// 获取当前选中的配置
    public var currentConfiguration: ShadowsocksConfig? {
        guard let name = selectedConfigName else {
            return nil
        }
        return configurations[name]
    }
    
    /// 导入配置
    /// - Parameter url: 配置文件 URL
    /// - Throws: 导入失败时抛出错误
    public func importConfiguration(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        // 尝试解析单个配置
        if let config = try? decoder.decode(ShadowsocksConfig.self, from: data) {
            let name = url.deletingPathExtension().lastPathComponent
            addConfiguration(config, name: name)
            return
        }
        
        // 尝试解析配置数组
        if let configs = try? decoder.decode([String: ShadowsocksConfig].self, from: data) {
            for (name, config) in configs {
                addConfiguration(config, name: name)
            }
            return
        }
        
        throw ShadowsocksError.invalidConfiguration("无效的配置文件格式")
    }
    
    /// 导出配置
    /// - Parameters:
    ///   - name: 配置名称
    ///   - url: 导出路径
    /// - Throws: 导出失败时抛出错误
    public func exportConfiguration(name: String, to url: URL) throws {
        guard let config = configurations[name] else {
            throw ShadowsocksError.invalidConfiguration("配置不存在")
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: url)
    }
    
    /// 导出所有配置
    /// - Parameter url: 导出路径
    /// - Throws: 导出失败时抛出错误
    public func exportAllConfigurations(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configurations)
        try data.write(to: url)
    }
}

// MARK: - Codable Support

extension ShadowsocksConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case server
        case serverPort
        case password
        case method
        case localAddress
        case localPort
        case enableUDP
        case timeout
        case dnsServer
        case mode
    }
}

extension ProxyMode: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "global":
            self = .global
        case "whitelist":
            self = .whitelist
        case "blacklist":
            self = .blacklist
        default:
            self = .whitelist
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .global:
            try container.encode("global")
        case .whitelist:
            try container.encode("whitelist")
        case .blacklist:
            try container.encode("blacklist")
        }
    }
} 