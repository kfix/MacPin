// swift-tools-version:5.4
import PackageDescription

var excludeds = [] as [String]
#if os(macOS)
excludeds.append("_ios")
#elseif os(iOS)
excludeds.append("_macos")
#endif

let package = Package(
    name: "MacPin",
    //platforms: [.iOS(.v13),.macOS(.v10_15)],
    // whines about a lot of unguarded calls to 10.15.4 apis
    platforms: [.iOS(.v13),.macOS(.v11)],
    products: [
        .library(name: "MacPin", type: .dynamic, targets: ["MacPin"]),
        .executable(name: "MacPin_static", targets: ["MacPin_static"]),
    ],
    dependencies: [
        .package(path: "modules/WebKitPrivates"),
        .package(path: "modules/ViewPrivates"),
        .package(path: "modules/UserNotificationPrivates"),
        .package(path: "modules/JavaScriptCorePrivates"),
        .package(path: "modules/Linenoise"),
        .package(path: "modules/UTIKit"),
    ],
    targets: [
        .target(
            name: "MacPin",
            dependencies: [
                "WebKitPrivates",
                "JavaScriptCorePrivates",
                "ViewPrivates",
                "UserNotificationPrivates",
                "Linenoise",
                "UTIKit",
            ],
            exclude: excludeds,
            swiftSettings: [
                .unsafeFlags([
                    "-suppress-warnings",
                ]),
                //.define("SAFARIDBG"),
                //.define("DEBUG"),
                //.define("DBGMENU"),
                //.define("APP2JSLOG"),
                //.define("WK2LOG"),
            ]
        ),
        // somehow have a target that makes libMacPin.dylib into a .framework
        .executableTarget(
            name: "MacPin_static",
            dependencies: ["MacPin"]
        ),
        .executableTarget(
            name: "MacPin_stub",
            dependencies: [],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path:@loader_path/../Frameworks"])
            ]
        ),

    ]
)

#if os(macOS)
package.products.append(
    .executable(name: "MacPin_stub", targets: ["MacPin_stub"])
)
#endif
