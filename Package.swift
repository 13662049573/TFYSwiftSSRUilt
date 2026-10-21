// swift-tools-version:5.9
import PackageDescription

let packageRoot = "TFYSwiftSSRKit"
let libevRoot = "\(packageRoot)/shadowsocks-libev"
let rustRoot = "\(packageRoot)/shadowsocks-rust"

let sharedPreprocessorDefines: [CSetting] = [
    .define("HAVE_CONFIG_H", to: "1"),
    .define("PCRE_STATIC", to: "1"),
    .define("SUPPORT_UTF8", to: "1"),
    .define("SUPPORT_UCP", to: "1"),
    .define("SUPPORT_PCRE8", to: "1"),
    .define("HAVE_PCRE_H", to: "1"),
    .define("PCRE_DEFINITION_CHANGED", to: "1"),
    .define("PCRE_OVERRIDE_MALLOC", to: "1"),
    .define("NO_RECURSE", to: "1"),
    .define("ANTINAT_IMPLEMENTATION", to: "1"),
    .define("PRIVOXY_IMPLEMENTATION", to: "1"),
    .define("DEFINE_MISSING_SYMBOLS", to: "1"),
]

let sharedHeaderSearchPaths: [CSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("Base"),
    .headerSearchPath("Core"),
    .headerSearchPath("Service"),
    .headerSearchPath("TFYCoreFactory"),
    .headerSearchPath("Rules"),
    .headerSearchPath("\(libevRoot)/libsodium/include"),
    .headerSearchPath("\(libevRoot)/mbedtls/include"),
    .headerSearchPath("\(libevRoot)/libev/include"),
    .headerSearchPath("\(libevRoot)/libcork/include"),
    .headerSearchPath("\(libevRoot)/pcre/include"),
    .headerSearchPath("\(libevRoot)/antinat/include"),
    .headerSearchPath("\(libevRoot)/privoxy/include"),
    .headerSearchPath("\(rustRoot)/include"),
]

/// iOS static archives from the `shadowsocks-libev` pod subspec (`*_ios.a`).
private let libevIOSArchives: [(path: String, forceLoad: Bool)] = [
    ("\(libevRoot)/shadowsocks/lib/libshadowsocks-libev_ios.a", true),
    ("\(libevRoot)/libev/lib/libev_ios.a", false),
    ("\(libevRoot)/libsodium/lib/libsodium_ios.a", false),
    ("\(libevRoot)/openssl/lib/libcrypto_ios.a", false),
    ("\(libevRoot)/openssl/lib/libssl_ios.a", false),
    ("\(libevRoot)/c-ares/lib/libcares_ios.a", false),
    ("\(libevRoot)/pcre/lib/libpcre_ios.a", false),
    ("\(libevRoot)/pcre/lib/libpcreposix_ios.a", false),
    ("\(libevRoot)/libcork/lib/libcork_ios.a", false),
    ("\(libevRoot)/libipset/lib/libipset_ios.a", false),
    ("\(libevRoot)/mbedtls/lib/libmbedtls_ios.a", false),
    ("\(libevRoot)/mbedtls/lib/libmbedcrypto_ios.a", false),
    ("\(libevRoot)/mbedtls/lib/libmbedx509_ios.a", false),
    ("\(libevRoot)/libmaxminddb/lib/libmaxminddb_ios.a", false),
    ("\(libevRoot)/antinat/lib/libantinat_ios.a", true),
    ("\(libevRoot)/privoxy/lib/libprivoxy_ios.a", true),
    ("\(libevRoot)/udns/lib/libudns_ios.a", false),
]

/// macOS static archives from the `shadowsocks-libev` pod subspec (`*_macos.a`).
private let libevMacOSArchivePaths: [String] = [
    "\(libevRoot)/shadowsocks/lib/libshadowsocks-libev_macos.a",
    "\(libevRoot)/libev/lib/libev_macos.a",
    "\(libevRoot)/libsodium/lib/libsodium_macos.a",
    "\(libevRoot)/openssl/lib/libcrypto_macos.a",
    "\(libevRoot)/openssl/lib/libssl_macos.a",
    "\(libevRoot)/c-ares/lib/libcares_macos.a",
    "\(libevRoot)/pcre/lib/libpcre_macos.a",
    "\(libevRoot)/pcre/lib/libpcreposix_macos.a",
    "\(libevRoot)/libcork/lib/libcork_macos.a",
    "\(libevRoot)/libipset/lib/libipset_macos.a",
    "\(libevRoot)/mbedtls/lib/libmbedtls_macos.a",
    "\(libevRoot)/mbedtls/lib/libmbedcrypto_macos.a",
    "\(libevRoot)/mbedtls/lib/libmbedx509_macos.a",
    "\(libevRoot)/libmaxminddb/lib/libmaxminddb_macos.a",
    "\(libevRoot)/antinat/lib/libantinat_macos.a",
    "\(libevRoot)/privoxy/lib/libprivoxy_macos.a",
    "\(libevRoot)/udns/lib/libudns_macos.a",
]

private func archiveLinkerFlags(_ archives: [(path: String, forceLoad: Bool)]) -> [String] {
    var flags: [String] = []
    for archive in archives {
        if archive.forceLoad {
            flags += ["-Xlinker", "-force_load", "-Xlinker", archive.path]
        } else {
            flags.append(archive.path)
        }
    }
    return flags
}

private let commonLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("c"),
    .linkedLibrary("resolv"),
    .linkedLibrary("z"),
    .linkedFramework("NetworkExtension"),
]

private let iosLinkerSettings: [LinkerSetting] = [
    .linkedFramework("UIKit", .when(platforms: [.iOS])),
    .unsafeFlags(
        archiveLinkerFlags(libevIOSArchives) + [
            "\(rustRoot)/lib/libss_ios.a",
            "-ObjC",
            "-all_load",
        ],
        .when(platforms: [.iOS])
    ),
]

private let macosLinkerSettings: [LinkerSetting] = [
    .linkedFramework("AppKit", .when(platforms: [.macOS])),
    .unsafeFlags(
        libevMacOSArchivePaths + [
            "\(rustRoot)/lib/libss_macos.a",
            "-ObjC",
            "-all_load",
        ],
        .when(platforms: [.macOS])
    ),
]

let package = Package(
    name: "TFYSwiftSSRKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "TFYSwiftSSRKit",
            targets: ["TFYSwiftSSRKit"]
        ),
    ],
    targets: [
        .target(
            name: "TFYSwiftSSRKit",
            path: packageRoot,
            exclude: [
                "shadowsocks-libev",
                "shadowsocks-rust",
            ],
            cSettings: sharedPreprocessorDefines + sharedHeaderSearchPaths,
            linkerSettings: commonLinkerSettings + iosLinkerSettings + macosLinkerSettings
        ),
    ]
)
