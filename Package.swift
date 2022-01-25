// swift-tools-version:5.4
import PackageDescription
import Foundation
let package = Package(
    name: "MacPin",
    //platforms: [.macOS(.v10_15)],
    // whines about a lot of unguarded calls to 10.15.4 apis
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "MacPin", type: .dynamic, targets: ["MacPin"]),
        .executable(name: "MacPin_static", targets: ["MacPin_static"]),
        .executable(name: "MacPin_stub", targets: ["MacPin_stub"]),
    ],
    dependencies: [
        .package(path: "modules/Linenoise"),
        .package(path: "modules/UTIKit"),
    ],
    targets: [
        .systemLibrary(
            name: "WebKitPrivates",
            path: "modules/WebKitPrivates"
        ),
        .systemLibrary(
            name: "ViewPrivates",
            path: "modules/ViewPrivates"
        ),
        .systemLibrary(
            name: "UserNotificationPrivates",
            path: "modules/UserNotificationPrivates"
        ),
        .systemLibrary(
            name: "JavaScriptCorePrivates",
            path: "modules/JavaScriptCorePrivates"
        ),
    ]
)
if let iosvar = ProcessInfo.processInfo.environment["MACPIN_IOS"], !iosvar.isEmpty {
    package.platforms = [.iOS(.v13)]
    package.products = [ .executable(name: "MacPin", targets: ["MacPin"]) ]
    package.targets.append(
        .executableTarget(
            name: "MacPin",
            dependencies: [
                "WebKitPrivates",
                "JavaScriptCorePrivates",
                "ViewPrivates",
                "UserNotificationPrivates",
                "Linenoise",
                "UTIKit",
            ],
            path: "Sources/MacPinIOS"
        )
    )
} else {
    package.targets.append(contentsOf: [
        .target(name: "MacPin",
            dependencies: [
                "WebKitPrivates",
                "JavaScriptCorePrivates",
                "ViewPrivates",
                "UserNotificationPrivates",
                "Linenoise",
                "UTIKit",
            ],
            path: "Sources/MacPinOSX"
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
        )
    ])
}
