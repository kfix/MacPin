// swift-tools-version:5.4
import PackageDescription

var mp = "MacPinOSX"
// FIXME: need a way to define IOS so we can change the Sources
//   #if os() doesn't really work as its just matching the host runtime 
//mp = "MacPinIOS"

let package = Package(
    name: "MacPin",
    //platforms: [.iOS(.v13),.macOS(.v10_15)],
    // whines about a lot of unguarded calls to 10.15.4 apis
    platforms: [.iOS(.v13),.macOS(.v11)],
    products: [
        .library(name: "MacPin", type: .dynamic, targets: ["MacPin"]),
        .executable(name: "MacPin_static", targets: ["MacPin_static"]),
        .executable(name: "MacPin_stub", targets: ["MacPin_stub"]),
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
        .target(name: "MacPin",
            dependencies: [
                "WebKitPrivates",
                "JavaScriptCorePrivates",
                "ViewPrivates",
                "UserNotificationPrivates",
                "Linenoise",
                "UTIKit",
            ],
            path: "Sources/\(mp)",
            exclude: [
                "Package.swift"
            ]
        ),
        .executableTarget(
            name: "MacPin_static",
            dependencies: [
                .target(name: "MacPin")
            ]
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
