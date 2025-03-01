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
    private let vpnService = TFYVPNService.shared()
    private var config: TFYConfig?
    private var timer: Timer?
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let statusView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 75
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "未连接"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .systemRed
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let connectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("连接", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let serverTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "服务器地址"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let portTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "端口"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let methodTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "加密方法"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "密码"
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let trafficLabel: UILabel = {
        let label = UILabel()
        label.text = "上传: 0 KB | 下载: 0 KB"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let coreTypeSegmentedControl: UISegmentedControl = {
        let items = ["Rust", "C"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        return segmentedControl
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupVPNService()
        loadSavedConfig()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTrafficTimer()
        updateVPNStatus()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTrafficTimer()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "TFYSwiftSSR"
        
        // 添加子视图
        view.addSubview(containerView)
        containerView.addSubview(statusView)
        statusView.addSubview(statusLabel)
        containerView.addSubview(serverTextField)
        containerView.addSubview(portTextField)
        containerView.addSubview(methodTextField)
        containerView.addSubview(passwordTextField)
        containerView.addSubview(coreTypeSegmentedControl)
        containerView.addSubview(connectButton)
        containerView.addSubview(trafficLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 容器视图
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // 状态视图
            statusView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            statusView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusView.widthAnchor.constraint(equalToConstant: 150),
            statusView.heightAnchor.constraint(equalToConstant: 150),
            
            // 状态标签
            statusLabel.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            
            // 服务器输入框
            serverTextField.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: 30),
            serverTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            serverTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            serverTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // 端口输入框
            portTextField.topAnchor.constraint(equalTo: serverTextField.bottomAnchor, constant: 15),
            portTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            portTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            portTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // 加密方法输入框
            methodTextField.topAnchor.constraint(equalTo: portTextField.bottomAnchor, constant: 15),
            methodTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            methodTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            methodTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // 密码输入框
            passwordTextField.topAnchor.constraint(equalTo: methodTextField.bottomAnchor, constant: 15),
            passwordTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            passwordTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // 核心类型选择器
            coreTypeSegmentedControl.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 20),
            coreTypeSegmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            coreTypeSegmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // 连接按钮
            connectButton.topAnchor.constraint(equalTo: coreTypeSegmentedControl.bottomAnchor, constant: 30),
            connectButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            connectButton.widthAnchor.constraint(equalToConstant: 200),
            connectButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 流量标签
            trafficLabel.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 20),
            trafficLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            trafficLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
        ])
        
        // 设置键盘隐藏手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupActions() {
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        coreTypeSegmentedControl.addTarget(self, action: #selector(coreTypeChanged), for: .valueChanged)
    }
    
    private func setupVPNService() {
        vpnService.delegate = self
        
        // 检查 VPN 权限
        vpnService.checkVPNPermission { [weak self] granted, error in
            if !granted {
                self?.showAlert(title: "VPN 权限", message: "请在设置中允许 VPN 配置")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func connectButtonTapped() {
        if vpnService.state == .connected || vpnService.state == .connecting {
            // 断开连接
            vpnService.stop { [weak self] error in
                if let error = error {
                    self?.showAlert(title: "错误", message: "断开连接失败: \(error.localizedDescription)")
                }
            }
        } else {
            // 连接
            guard let server = serverTextField.text, !server.isEmpty,
                  let portText = portTextField.text, !portText.isEmpty,
                  let port = UInt16(portText),
                  let method = methodTextField.text, !method.isEmpty,
                  let password = passwordTextField.text, !password.isEmpty else {
                showAlert(title: "错误", message: "请填写所有字段")
                return
            }
            
            // 创建配置
            let config = TFYConfig(server: server, port: port, method: method, password: password)
            config.preferredCore = coreTypeSegmentedControl.selectedSegmentIndex == 0 ? .rust : .C
            config.localAddress = "127.0.0.1"
            config.localPort = 1080
            config.timeout = 60
            
            self.config = config
            saveConfig()
            
            // 安装 VPN 配置
            vpnService.installVPNProfile { [weak self] error in
                if let error = error {
                    self?.showAlert(title: "错误", message: "安装 VPN 配置失败: \(error.localizedDescription)")
                    return
                }
                
                // 启动 VPN
                self?.vpnService.start(config: config) { error in
                    if let error = error {
                        self?.showAlert(title: "错误", message: "启动 VPN 失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    @objc private func coreTypeChanged() {
        if let config = config {
            config.preferredCore = coreTypeSegmentedControl.selectedSegmentIndex == 0 ? .rust : .C
            saveConfig()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Helper Methods
    private func updateVPNStatus() {
        switch vpnService.state {
        case .disconnected:
            statusLabel.text = "未连接"
            statusLabel.textColor = .systemRed
            connectButton.setTitle("连接", for: .normal)
            connectButton.backgroundColor = .systemBlue
            
        case .connecting:
            statusLabel.text = "连接中..."
            statusLabel.textColor = .systemOrange
            connectButton.setTitle("取消", for: .normal)
            connectButton.backgroundColor = .systemOrange
            
        case .connected:
            statusLabel.text = "已连接"
            statusLabel.textColor = .systemGreen
            connectButton.setTitle("断开", for: .normal)
            connectButton.backgroundColor = .systemRed
            
        case .disconnecting:
            statusLabel.text = "断开中..."
            statusLabel.textColor = .systemOrange
            connectButton.setTitle("断开中...", for: .normal)
            connectButton.backgroundColor = .systemGray
            connectButton.isEnabled = false
            
        case .reconnecting:
            statusLabel.text = "重连中..."
            statusLabel.textColor = .systemOrange
            connectButton.setTitle("取消", for: .normal)
            connectButton.backgroundColor = .systemOrange
            
        case .invalid:
            statusLabel.text = "无效状态"
            statusLabel.textColor = .systemGray
            connectButton.setTitle("连接", for: .normal)
            connectButton.backgroundColor = .systemBlue
            
        @unknown default:
            statusLabel.text = "未知状态"
            statusLabel.textColor = .systemGray
            connectButton.setTitle("连接", for: .normal)
            connectButton.backgroundColor = .systemBlue
        }
    }
    
    private func updateTrafficStats() {
        let uploadTraffic = formatTraffic(vpnService.uploadTraffic)
        let downloadTraffic = formatTraffic(vpnService.downloadTraffic)
        trafficLabel.text = "上传: \(uploadTraffic) | 下载: \(downloadTraffic)"
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
    
    private func startTrafficTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTrafficStats()
        }
    }
    
    private func stopTrafficTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Config Persistence
    private func saveConfig() {
        guard let config = config else { return }
        
        let defaults = UserDefaults.standard
        defaults.set(config.server, forKey: "server")
        defaults.set(config.serverPort, forKey: "port")
        defaults.set(config.method, forKey: "method")
        defaults.set(config.password, forKey: "password")
        defaults.set(config.preferredCore.rawValue, forKey: "coreType")
    }
    
    private func loadSavedConfig() {
        let defaults = UserDefaults.standard
        
        if let server = defaults.string(forKey: "server"),
           let method = defaults.string(forKey: "method"),
           let password = defaults.string(forKey: "password") {
            
            let port = UInt16(defaults.integer(forKey: "port"))
            let coreType = defaults.integer(forKey: "coreType")
            
            serverTextField.text = server
            portTextField.text = String(port)
            methodTextField.text = method
            passwordTextField.text = password
            coreTypeSegmentedControl.selectedSegmentIndex = coreType
            
            // 创建配置
            let config = TFYConfig(server: server, port: port, method: method, password: password)
            config.preferredCore = coreType == 0 ? .rust : .C
            config.localAddress = "127.0.0.1"
            config.localPort = 1080
            config.timeout = 60
            
            self.config = config
        }
    }
}

// MARK: - TFYVPNServiceDelegate
extension ViewController: TFYVPNServiceDelegate {
    func vpnService(_ service: TFYVPNService, didChangeState state: TFYVPNState) {
        DispatchQueue.main.async { [weak self] in
            self?.updateVPNStatus()
        }
    }
    
    func vpnService(_ service: TFYVPNService, didUpdateTraffic upload: UInt64, download: UInt64) {
        DispatchQueue.main.async { [weak self] in
            self?.updateTrafficStats()
        }
    }
    
    func vpnService(_ service: TFYVPNService, didEncounterError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.showAlert(title: "错误", message: error.localizedDescription)
        }
    }
}

