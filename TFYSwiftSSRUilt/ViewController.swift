//
//  ViewController.swift
//  TFYSwiftSSRUilt
//
//  Created by 田风有 on 2025/2/2.
//

import UIKit
import NetworkExtension
import TFYSwiftSSRKit


class ViewController: UIViewController {
    
    // MARK: - Properties
    private let vpnManager = VPNManager.shared()
    private var currentConfig: SSConfig?
    private var wormhole: MMWormhole?
    private var previousUpload: UInt64 = 0
    private var previousDownload: UInt64 = 0
    
    // MARK: - UI Components
    private lazy var mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 30
        stack.alignment = .center
        return stack
    }()
    
    private lazy var connectionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 40
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        
        // 设置图标
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        button.setImage(UIImage(systemName: "power.circle.fill")?
            .withConfiguration(config), for: .normal)
        
        button.addTarget(self, action: #selector(connectionButtonTapped), for: .touchUpInside)
        
        // 添加阴影效果
        button.layer.shadowColor = UIColor.systemBlue.cgColor
        button.layer.shadowOffset = .zero
        button.layer.shadowRadius = 10
        button.layer.shadowOpacity = 0.3
        
        return button
    }()
    
    private lazy var statusView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 15
        
        // 添加毛玻璃效果
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.frame = view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blur)
        
        return view
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .label
        label.text = "未连接"
        return label
    }()
    
    private lazy var trafficView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 15
        
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.frame = view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blur)
        
        return view
    }()
    
    private lazy var trafficStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        return stack
    }()
    
    private lazy var uploadLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGreen
        label.text = "上传: 0 B/s"
        return label
    }()
    
    private lazy var downloadLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemBlue
        label.text = "下载: 0 B/s"
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDefaultConfig()
        setupVPNObserver()
        setupWormhole()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "TFY加速器"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // 添加主要视图
        view.addSubview(mainStackView)
        mainStackView.addArrangedSubview(connectionButton)
        mainStackView.addArrangedSubview(statusView)
        mainStackView.addArrangedSubview(trafficView)
        
        // 添加状态标签
        statusView.addSubview(statusLabel)
        
        // 添加流量标签
        trafficView.addSubview(trafficStackView)
        trafficStackView.addArrangedSubview(uploadLabel)
        trafficStackView.addArrangedSubview(downloadLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 主栈视图约束
            mainStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // 连接按钮约束
            connectionButton.widthAnchor.constraint(equalToConstant: 80),
            connectionButton.heightAnchor.constraint(equalToConstant: 80),
            
            // 状态视图约束
            statusView.widthAnchor.constraint(equalTo: mainStackView.widthAnchor),
            statusView.heightAnchor.constraint(equalToConstant: 50),
            
            // 流量视图约束
            trafficView.widthAnchor.constraint(equalTo: mainStackView.widthAnchor),
            trafficView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        // 状态标签约束
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor)
        ])
        
        // 流量栈视图约束
        trafficStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trafficStackView.leadingAnchor.constraint(equalTo: trafficView.leadingAnchor, constant: 15),
            trafficStackView.trailingAnchor.constraint(equalTo: trafficView.trailingAnchor, constant: -15),
            trafficStackView.centerYAnchor.constraint(equalTo: trafficView.centerYAnchor)
        ])
    }
    
    private func setupDefaultConfig() {
        // SS URL: ss://chacha20-ietf:kedang@123@115.236.101.106:18989
        let config = SSConfig(serverAddress: "115.236.101.106",
                               serverPort: 18989,
                               password: "kedang@123",
                               method: "chacha20-ietf",
                               timeout: 600)
        
        // 设置必要的额外配置
        config.providerBundleIdentifier = "group.com.vpn.ios.soms.somsDemo"
        config.settingsTitle = "TFYVPN"
        currentConfig = config
    }
    
    private func setupWormhole() {
        wormhole = MMWormhole(applicationGroupIdentifier: "group.com.vpn.ios.soms.somsDemo",
                             optionalDirectory: "vpn_tunnel")
    }
    
    private func setupVPNObserver() {
        // 注册 VPN 状态监听
        vpnManager.registerDelegate(self)
    }
    
    // MARK: - Actions
    @objc private func connectionButtonTapped() {
        guard let config = currentConfig else {
            showAlert(title: "错误", message: "SS 配置未找到")
            return
        }
        
        animateConnectionButton(true)
        
        // 使用正确的方法名
        vpnManager.startVPN(config, status: true) { [weak self] status, succeed in
            DispatchQueue.main.async {
                self?.animateConnectionButton(false)
                
                switch status {
                case 0:
                    self?.showAlert(title: "提示", message: "VPN正在连接中，请勿重复点击")
                case -1:
                    self?.showAlert(title: "错误", message: "VPN配置失败")
                case 1:
                    self?.showAlert(title: "提示", message: "首次配置成功")
                case 2:
                    self?.showAlert(title: "错误", message: "VPN启动失败")
                case 3:
                    print("VPN启动成功")
                default:
                    break
                }
            }
        }
    }
    
    @objc private func settingsButtonTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // 添加服务器配置选项
        alert.addAction(UIAlertAction(title: "服务器配置", style: .default) { [weak self] _ in
            self?.showServerConfigAlert()
        })
        
        alert.addAction(UIAlertAction(title: "重置VPN配置", style: .destructive) { [weak self] _ in
            self?.resetVPNConfiguration()
        })
        
        alert.addAction(UIAlertAction(title: "关于", style: .default) { [weak self] _ in
            self?.showAboutInfo()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Helper Methods
    private func updateConnectionState(_ connected: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.connectionButton.backgroundColor = connected ? .systemGreen : .systemBlue
            self.connectionButton.layer.shadowColor = connected ? UIColor.systemGreen.cgColor : UIColor.systemBlue.cgColor
        }
        
        // 更新状态文本
        statusLabel.text = connected ? "已连接" : "未连接"
        statusLabel.textColor = connected ? .systemGreen : .label
    }
    
    private func updateTraffic(upload: UInt64, download: UInt64) {
        let uploadSpeed = upload - previousUpload
        let downloadSpeed = download - previousDownload
        
        DispatchQueue.main.async {
            self.uploadLabel.text = "上传: \(self.formatSpeed(uploadSpeed))/s"
            self.downloadLabel.text = "下载: \(self.formatSpeed(downloadSpeed))/s"
        }
        
        previousUpload = upload
        previousDownload = download
    }
    
    private func animateConnectionButton(_ connecting: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.connectionButton.alpha = connecting ? 0.5 : 1.0
            self.connectionButton.transform = connecting ? 
                CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
        }
    }
    
    private func formatSpeed(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showServerConfigAlert() {
        let alert = UIAlertController(title: "服务器配置", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "服务器地址"
            textField.text = self.currentConfig?.serverAddress
        }
        
        alert.addTextField { textField in
            textField.placeholder = "端口"
            textField.text = self.currentConfig?.serverPort.description
            textField.keyboardType = .numberPad
        }
        
        alert.addTextField { textField in
            textField.placeholder = "密码"
            textField.text = self.currentConfig?.password
            textField.isSecureTextEntry = true
        }
        
        alert.addTextField { textField in
            textField.placeholder = "加密方法"
            textField.text = self.currentConfig?.method
        }
        
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self, weak alert] _ in
            guard let alert = alert,
                  let serverField = alert.textFields?[0],
                  let portField = alert.textFields?[1],
                  let passwordField = alert.textFields?[2],
                  let methodField = alert.textFields?[3],
                  let serverAddress = serverField.text,
                  let portString = portField.text,
                  let port = UInt16(portString),
                  let password = passwordField.text,
                  let method = methodField.text
            else {
                self?.showAlert(title: "错误", message: "请填写完整的配置信息")
                return
            }
            
            self?.currentConfig = SSConfig(
                serverAddress: serverAddress,
                serverPort: port,
                password: password,
                method: method,
                timeout: 600
            )
            
            self?.showAlert(title: "成功", message: "配置已保存")
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func resetVPNConfiguration() {
        // 实现重置VPN配置的逻辑
        showAlert(title: "功能未实现", message: "此功能尚未实现")
    }
    
    private func showAboutInfo() {
        // 实现显示关于信息的逻辑
        showAlert(title: "功能未实现", message: "此功能尚未实现")
    }
    
    private func stopVPN() {
        vpnManager.stopVPNConnect()
    }
    
    deinit {
        vpnManager.removeDelegate()
    }
}

// MARK: - TFYVpnManagerDelegate
extension ViewController: VPNManagerDelegate {
    func nbVpnStatusDidChange(_ status: VPNStatus) {
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .invalid:
                self?.statusLabel.text = "VPN 不可用"
                self?.updateConnectionState(false)
            case .disconnected:
                self?.statusLabel.text = "未连接"
                self?.updateConnectionState(false)
            case .connecting:
                self?.statusLabel.text = "连接中..."
                self?.animateConnectionButton(true)
            case .connected:
                self?.statusLabel.text = "已连接"
                self?.updateConnectionState(true)
            case .disconnecting:
                self?.statusLabel.text = "断开连接中..."
                self?.animateConnectionButton(true)
            @unknown default:
                break
            }
        }
    }
    
    func nbNotVipJumpToPurchase() {
        showAlert(title: "提示", message: "请先开通会员")
    }
}

