import Foundation

/// 代理规则类型
public enum RuleType {
    case domain(String)      // 域名规则
    case ipRange(String)     // IP 范围规则
    case keyword(String)     // 关键词规则
    case userAgent(String)   // User-Agent 规则
}

/// 代理动作
public enum RuleAction {
    case proxy              // 使用代理
    case direct             // 直连
    case reject             // 拒绝
}

/// 代理规则
public struct ProxyRule {
    /// 规则类型
    public let type: RuleType
    /// 规则动作
    public let action: RuleAction
    /// 规则描述
    public let description: String?
    
    public init(type: RuleType, action: RuleAction, description: String? = nil) {
        self.type = type
        self.action = action
        self.description = description
    }
}

/// 代理模式
public enum ProxyMode {
    case global             // 全局模式
    case whitelist          // 白名单模式
    case blacklist          // 黑名单模式
}

/// 规则管理器
public class RuleManager {
    /// 单例
    public static let shared = RuleManager()
    
    /// 当前代理模式
    public var mode: ProxyMode = .whitelist
    
    /// 规则列表
    public private(set) var rules: [ProxyRule] = []
    
    /// 用户自定义规则
    public private(set) var userRules: [ProxyRule] = []
    
    /// 初始化
    private init() {
        loadDefaultRules()
        loadUserRules()
    }
    
    /// 加载默认规则
    private func loadDefaultRules() {
        // 从内置规则文件加载
        if let url = Bundle(for: RuleManager.self).url(forResource: "default_rules", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            rules = json.compactMap { parseRule(from: $0) }
        } else {
            // 如果找不到默认规则文件，使用内置的基本规则
            rules = [
                ProxyRule(type: .domain("google.com"), action: .proxy, description: "Google"),
                ProxyRule(type: .domain("facebook.com"), action: .proxy, description: "Facebook"),
                ProxyRule(type: .domain("twitter.com"), action: .proxy, description: "Twitter"),
                ProxyRule(type: .domain("github.com"), action: .proxy, description: "GitHub"),
                ProxyRule(type: .domain("baidu.com"), action: .direct, description: "百度"),
                ProxyRule(type: .domain("qq.com"), action: .direct, description: "腾讯"),
                ProxyRule(type: .ipRange("192.168.0.0/16"), action: .direct, description: "局域网"),
                ProxyRule(type: .keyword("adware"), action: .reject, description: "广告软件")
            ]
        }
    }
    
    /// 加载用户规则
    private func loadUserRules() {
        // 首先尝试从用户文档目录加载
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("user_rules.json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            userRules = json.compactMap { parseRule(from: $0) }
        } else {
            // 如果用户文档目录中没有规则文件，尝试从 Bundle 中加载模板
            if let url = Bundle(for: RuleManager.self).url(forResource: "user_rules", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                userRules = json.compactMap { parseRule(from: $0) }
                // 保存到用户文档目录
                saveUserRules()
            }
        }
    }
    
    /// 解析规则
    private func parseRule(from json: [String: Any]) -> ProxyRule? {
        guard let typeStr = json["type"] as? String,
              let actionStr = json["action"] as? String,
              let value = json["value"] as? String else {
            return nil
        }
        
        let type: RuleType
        switch typeStr {
        case "domain":
            type = .domain(value)
        case "ip":
            type = .ipRange(value)
        case "keyword":
            type = .keyword(value)
        case "useragent":
            type = .userAgent(value)
        default:
            return nil
        }
        
        let action: RuleAction
        switch actionStr {
        case "proxy":
            action = .proxy
        case "direct":
            action = .direct
        case "reject":
            action = .reject
        default:
            return nil
        }
        
        return ProxyRule(type: type, action: action, description: json["description"] as? String)
    }
    
    /// 添加用户规则
    public func addUserRule(_ rule: ProxyRule) {
        userRules.append(rule)
        saveUserRules()
    }
    
    /// 删除用户规则
    public func removeUserRule(at index: Int) {
        guard index < userRules.count else { return }
        userRules.remove(at: index)
        saveUserRules()
    }
    
    /// 保存用户规则
    private func saveUserRules() {
        let json = userRules.map { rule -> [String: Any] in
            var dict: [String: Any] = [:]
            
            switch rule.type {
            case .domain(let value):
                dict["type"] = "domain"
                dict["value"] = value
            case .ipRange(let value):
                dict["type"] = "ip"
                dict["value"] = value
            case .keyword(let value):
                dict["type"] = "keyword"
                dict["value"] = value
            case .userAgent(let value):
                dict["type"] = "useragent"
                dict["value"] = value
            }
            
            switch rule.action {
            case .proxy:
                dict["action"] = "proxy"
            case .direct:
                dict["action"] = "direct"
            case .reject:
                dict["action"] = "reject"
            }
            
            if let description = rule.description {
                dict["description"] = description
            }
            
            return dict
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("user_rules.json") {
            try? data.write(to: url)
        }
    }
    
    /// 生成 PAC 文件
    public func generatePACFile() -> String {
        var pacContent = """
        function FindProxyForURL(url, host) {
            // 代理服务器
            var proxy = "SOCKS5 127.0.0.1:1080; SOCKS 127.0.0.1:1080; DIRECT;";
            
            // 判断代理模式
            var mode = "\(mode)";
            
            // 直连列表
            var directList = [];
            
            // 代理列表
            var proxyList = [];
            
            // 拒绝列表
            var rejectList = [];
            
        """
        
        // 添加规则
        for rule in rules + userRules {
            let list: String
            switch rule.action {
            case .direct:
                list = "directList"
            case .proxy:
                list = "proxyList"
            case .reject:
                list = "rejectList"
            }
            
            switch rule.type {
            case .domain(let domain):
                pacContent += "\(list).push('\(domain)');\n"
            case .ipRange(let ip):
                pacContent += "\(list).push('\(ip)');\n"
            case .keyword(let keyword):
                pacContent += "\(list).push('*\(keyword)*');\n"
            case .userAgent(let ua):
                // User-Agent 规则需要特殊处理
                pacContent += """
                    if (navigator.userAgent.indexOf('\(ua)') !== -1) {
                        return proxy;
                    }
                    
                """
            }
        }
        
        // 添加判断逻辑
        pacContent += """
            // 检查是否匹配规则
            function checkRules(rules) {
                for (var i = 0; i < rules.length; i++) {
                    if (shExpMatch(host, rules[i])) {
                        return true;
                    }
                }
                return false;
            }
            
            // 全局模式
            if (mode === 'global') {
                return proxy;
            }
            
            // 检查拒绝列表
            if (checkRules(rejectList)) {
                return "REJECT";
            }
            
            // 白名单模式
            if (mode === 'whitelist') {
                if (checkRules(directList)) {
                    return "DIRECT";
                }
                return proxy;
            }
            
            // 黑名单模式
            if (mode === 'blacklist') {
                if (checkRules(proxyList)) {
                    return proxy;
                }
                return "DIRECT";
            }
            
            // 默认直连
            return "DIRECT";
        }
        """
        
        return pacContent
    }
    
    /// 检查 URL 是否需要代理
    public func shouldProxy(url: URL) -> Bool {
        let host = url.host ?? ""
        
        // 全局模式
        if mode == .global {
            return true
        }
        
        // 检查规则
        for rule in rules + userRules {
            if matchesRule(host: host, url: url, rule: rule) {
                switch rule.action {
                case .proxy:
                    return mode == .whitelist
                case .direct:
                    return mode == .blacklist
                case .reject:
                    return false
                }
            }
        }
        
        // 默认行为
        return mode == .whitelist
    }
    
    /// 检查是否匹配规则
    private func matchesRule(host: String, url: URL, rule: ProxyRule) -> Bool {
        switch rule.type {
        case .domain(let domain):
            return host.hasSuffix(domain)
        case .ipRange(let ip):
            // 简单的 IP 匹配，实际应该使用 IP 范围检查
            return host == ip
        case .keyword(let keyword):
            return url.absoluteString.contains(keyword)
        case .userAgent(let ua):
            // User-Agent 规则需要在实际请求时检查
            return false
        }
    }
} 