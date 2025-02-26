#![allow(non_snake_case)]

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicI32, AtomicU64, AtomicPtr, Ordering};
use log::{self, LevelFilter};
use shadowsocks::config::ServerConfig;
use shadowsocks::crypto::CipherKind;
use shadowsocks::plugin::PluginConfig;
use shadowsocks::config::Mode;
use shadowsocks_service::{
    config::{Config, ConfigType, ServerInstanceConfig},
    run_local,
};
use serde_json::Value;
use std::net::SocketAddr;
use std::str::FromStr;
use tokio::sync::oneshot;
use std::sync::OnceLock;

// 全局状态管理
static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
static SHUTDOWN_TX: AtomicPtr<oneshot::Sender<()>> = AtomicPtr::new(std::ptr::null_mut());
static CURRENT_STATE: AtomicI32 = AtomicI32::new(0);
static UPLOAD_TRAFFIC: AtomicU64 = AtomicU64::new(0);
static DOWNLOAD_TRAFFIC: AtomicU64 = AtomicU64::new(0);
static LAST_ERROR: OnceLock<String> = OnceLock::new();
static CURRENT_MODE: AtomicI32 = AtomicI32::new(0);

#[no_mangle]
pub extern "C" fn ss_init() {
    env_logger::Builder::new()
        .filter_level(LevelFilter::Info)
        .format_timestamp_millis()
        .init();
    
    // 初始化 tokio runtime
    if RUNTIME.get().is_none() {
        if let Ok(rt) = tokio::runtime::Runtime::new() {
            let _ = RUNTIME.set(rt);
        }
    }
    
    log::info!("Shadowsocks Rust 1.22.0 initialized");
}

#[no_mangle]
pub extern "C" fn ss_start(config_ptr: *const c_char) -> i32 {
    if config_ptr.is_null() {
        log::error!("Configuration pointer is null");
        return -1;
    }

    let config_str = match unsafe { CStr::from_ptr(config_ptr) }.to_str() {
        Ok(s) => s,
        Err(e) => {
            log::error!("Failed to parse config string: {}", e);
            return -2;
        }
    };

    log::info!("Starting shadowsocks with config: {}", config_str);

    let json_value: Value = match serde_json::from_str(config_str) {
        Ok(v) => v,
        Err(e) => {
            log::error!("Failed to parse JSON: {}", e);
            return -3;
        }
    };

    let mut config = Config::new(ConfigType::Local);
    
    if let Some(server) = json_value.get("server") {
        if let Some(server_obj) = server.as_object() {
            // Get required fields
            let addr = match server_obj.get("server").and_then(|v| v.as_str()) {
                Some(addr_str) => match SocketAddr::from_str(addr_str) {
                    Ok(addr) => addr,
                    Err(e) => {
                        log::error!("Invalid server address format: {}", e);
                        return -4;
                    }
                },
                None => {
                    log::error!("Server address not found in config");
                    return -5;
                }
            };

            let password = match server_obj.get("password").and_then(|v| v.as_str()) {
                Some(pwd) => pwd.to_string(),
                None => {
                    log::error!("Password not found in config");
                    return -6;
                }
            };

            let method = match server_obj.get("method").and_then(|v| v.as_str()) {
                Some(m) => match CipherKind::from_str(m) {
                    Ok(cipher) => cipher,
                    Err(e) => {
                        log::error!("Invalid cipher method: {}", e);
                        return -7;
                    }
                },
                None => {
                    log::error!("Encryption method not found in config");
                    return -8;
                }
            };

            // Create server config
            let server_config = match ServerConfig::new(addr, password, method) {
                Ok(mut config) => {
                    // Set optional fields
                    if let Some(plugin) = server_obj.get("plugin").and_then(|v| v.as_str()) {
                        if let Some(plugin_opts) = server_obj.get("plugin_opts").and_then(|v| v.as_str()) {
                            let plugin_config = PluginConfig {
                                plugin: plugin.to_string(),
                                plugin_opts: Some(plugin_opts.to_string()),
                                plugin_args: Vec::new(),
                                plugin_mode: Mode::TcpOnly,
                            };
                            config.set_plugin(plugin_config);
                        }
                    }
                    
                    config
                },
                Err(e) => {
                    log::error!("Failed to create server config: {}", e);
                    return -9;
                }
            };

            // Create server instance config
            let server_instance = ServerInstanceConfig::with_server_config(server_config);
            config.server.push(server_instance);
            log::info!("Server configuration loaded successfully");
        }
    }

    // 创建新的 shutdown channel
    let (tx, _rx) = oneshot::channel();
    let tx_ptr = Box::into_raw(Box::new(tx));
    let old_ptr = SHUTDOWN_TX.swap(tx_ptr, Ordering::SeqCst);
    if !old_ptr.is_null() {
        unsafe {
            drop(Box::from_raw(old_ptr));
        }
    }
    CURRENT_STATE.store(1, Ordering::SeqCst);
    
    match tokio::runtime::Runtime::new() {
        Ok(rt) => {
            rt.block_on(async {
                match run_local(config).await {
                    Ok(_) => {
                        log::info!("Shadowsocks service stopped normally");
                        0
                    }
                    Err(e) => {
                        log::error!("Service exited with error: {}", e);
                        let _ = LAST_ERROR.set(e.to_string());
                        -10
                    }
                }
            })
        }
        Err(e) => {
            log::error!("Failed to create runtime: {}", e);
            let _ = LAST_ERROR.set(e.to_string());
            -11
        }
    }
}

#[no_mangle]
pub extern "C" fn ss_stop() {
    let tx_ptr = SHUTDOWN_TX.swap(std::ptr::null_mut(), Ordering::SeqCst);
    if !tx_ptr.is_null() {
        unsafe {
            let tx = Box::from_raw(tx_ptr);
            let _ = tx.send(());
        }
        CURRENT_STATE.store(0, Ordering::SeqCst);
        log::info!("Shadowsocks service stopped");
    } else {
        log::warn!("No active service to stop");
    }
}

#[no_mangle]
pub extern "C" fn ss_get_version() -> *const c_char {
    let version = CString::new("1.22.0").unwrap();
    version.into_raw()
}

#[no_mangle]
pub extern "C" fn ss_set_log_level(level: i32) {
    let filter = match level {
        0 => LevelFilter::Error,
        1 => LevelFilter::Warn,
        2 => LevelFilter::Info,
        3 => LevelFilter::Debug,
        4 => LevelFilter::Trace,
        _ => LevelFilter::Info,
    };
    log::set_max_level(filter);
}

#[no_mangle]
pub extern "C" fn ss_get_last_error() -> *const c_char {
    if let Some(error) = LAST_ERROR.get() {
        CString::new(error.as_str()).unwrap_or_else(|_| CString::new("").unwrap()).into_raw()
    } else {
        CString::new("").unwrap().into_raw()
    }
}

#[no_mangle]
pub extern "C" fn ss_get_state() -> i32 {
    CURRENT_STATE.load(Ordering::SeqCst)
}

#[no_mangle]
pub extern "C" fn ss_set_mode(mode: i32) {
    CURRENT_MODE.store(mode, Ordering::SeqCst);
    log::info!("Proxy mode set to: {}", if mode == 0 { "PAC" } else { "Global" });
}

#[no_mangle]
pub extern "C" fn ss_update_pac(rules: *const c_char) -> i32 {
    if rules.is_null() {
        let _ = LAST_ERROR.set("PAC rules pointer is null".to_string());
        return -1;
    }

    let rules_str = match unsafe { CStr::from_ptr(rules) }.to_str() {
        Ok(s) => s,
        Err(e) => {
            let _ = LAST_ERROR.set(format!("Invalid PAC rules string: {}", e));
            return -2;
        }
    };

    // 这里应该实现 PAC 规则的更新逻辑
    log::info!("Updating PAC rules, length: {}", rules_str.len());
    0
}
#[no_mangle]
pub extern "C" fn ss_get_traffic(upload: *mut u64, download: *mut u64) {
    if !upload.is_null() {
        unsafe {
            *upload = UPLOAD_TRAFFIC.load(Ordering::SeqCst);
        }
    }
    if !download.is_null() {
        unsafe {
            *download = DOWNLOAD_TRAFFIC.load(Ordering::SeqCst);
        }
    }
}

