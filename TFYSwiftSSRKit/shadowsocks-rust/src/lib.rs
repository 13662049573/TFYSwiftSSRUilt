#[no_mangle]
pub extern "C" fn ss_init() {
    shadowsocks::logger::init().unwrap();
}

#[no_mangle]
pub extern "C" fn ss_start(config: *const u8) -> i32 {
    // 实现启动逻辑
    0
}
