import Foundation

/// Shadowsocks 错误类型
public enum ShadowsocksError: LocalizedError {
    /// 二进制文件未找到
    case binaryNotFound
    /// 启动失败
    case startFailed(String)
    /// 配置无效
    case invalidConfiguration(String)
    /// 进程已在运行
    case processAlreadyRunning
    /// 未知错误
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Shadowsocks 二进制文件未找到"
        case .startFailed(let reason):
            return "Shadowsocks 启动失败: \(reason)"
        case .invalidConfiguration(let reason):
            return "Shadowsocks 配置无效: \(reason)"
        case .processAlreadyRunning:
            return "Shadowsocks 进程已在运行"
        case .unknown(let reason):
            return "未知错误: \(reason)"
        }
    }
}

/// Shadowsocks 日志级别
public enum ShadowsocksLogLevel: String {
    case error = "ERROR"
    case warn = "WARN"
    case info = "INFO"
    case debug = "DEBUG"
    case trace = "TRACE"
}

/// Shadowsocks 日志委托
public protocol ShadowsocksLogDelegate: AnyObject {
    /// 收到日志
    /// - Parameters:
    ///   - level: 日志级别
    ///   - message: 日志消息
    func shadowsocks(_ manager: ShadowsocksManager, didReceiveLog level: ShadowsocksLogLevel, message: String)
}

extension ShadowsocksManager {
    /// 解析日志级别和消息
    /// - Parameter line: 日志行
    /// - Returns: 日志级别和消息
    internal func parseLogLine(_ line: String) -> (level: ShadowsocksLogLevel, message: String)? {
        let levels: [ShadowsocksLogLevel] = [.error, .warn, .info, .debug, .trace]
        
        for level in levels {
            if line.contains("[\(level.rawValue)]") {
                let components = line.components(separatedBy: "[\(level.rawValue)]")
                if components.count > 1 {
                    return (level, components[1].trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        return (.info, line)
    }
} 