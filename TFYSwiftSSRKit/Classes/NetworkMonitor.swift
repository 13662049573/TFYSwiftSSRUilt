import Foundation
import Network
import SystemConfiguration

/// 网络状态
public enum NetworkStatus {
    case unavailable
    case wifi
    case cellular
    case ethernet
    case unknown
}

/// 代理状态
public enum ProxyStatus {
    case connecting
    case connected
    case disconnected
    case error(Error)
}

/// 网络监控委托
public protocol NetworkMonitorDelegate: AnyObject {
    /// 网络状态变化
    func networkStatusDidChange(_ status: NetworkStatus)
    /// 代理状态变化
    func proxyStatusDidChange(_ status: ProxyStatus)
}

/// 网络监控
public class NetworkMonitor {
    /// 单例
    public static let shared = NetworkMonitor()
    
    /// 网络状态监控
    private let monitor = NWPathMonitor()
    
    /// 当前网络状态
    public private(set) var status: NetworkStatus = .unknown
    
    /// 委托
    public weak var delegate: NetworkMonitorDelegate?
    
    /// 流量统计
    public private(set) var statistics = Statistics()
    
    /// 自动重连配置
    public var autoReconnect = true
    public var reconnectDelay: TimeInterval = 5
    
    /// 初始化
    private init() {
        setupMonitor()
    }
    
    /// 设置监控
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newStatus: NetworkStatus
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    newStatus = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    newStatus = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    newStatus = .ethernet
                } else {
                    newStatus = .unknown
                }
            } else {
                newStatus = .unavailable
            }
            
            if newStatus != self.status {
                self.status = newStatus
                DispatchQueue.main.async {
                    self.delegate?.networkStatusDidChange(newStatus)
                }
                
                // 处理自动重连
                if newStatus != .unavailable && self.autoReconnect {
                    self.handleAutoReconnect()
                }
            }
        }
        
        monitor.start(queue: DispatchQueue.global())
    }
    
    /// 处理自动重连
    private func handleAutoReconnect() {
        guard let manager = ShadowsocksManager.shared.currentConfig else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self else { return }
            
            do {
                try ShadowsocksManager.shared.start(with: manager)
                self.delegate?.proxyStatusDidChange(.connected)
            } catch {
                self.delegate?.proxyStatusDidChange(.error(error))
            }
        }
    }
    
    /// 流量统计结构
    public struct Statistics {
        /// 上传流量
        public private(set) var uploadBytes: UInt64 = 0
        /// 下载流量
        public private(set) var downloadBytes: UInt64 = 0
        
        /// 更新流量统计
        mutating func update(upload: UInt64, download: UInt64) {
            uploadBytes += upload
            downloadBytes += download
        }
        
        /// 重置统计
        mutating func reset() {
            uploadBytes = 0
            downloadBytes = 0
        }
    }
    
    /// 更新流量统计
    internal func updateStatistics(upload: UInt64, download: UInt64) {
        statistics.update(upload: upload, download: download)
    }
    
    /// 重置流量统计
    public func resetStatistics() {
        statistics.reset()
    }
    
    /// 析构函数
    deinit {
        monitor.cancel()
    }
} 