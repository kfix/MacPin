// swift-tools-version:5.10
import PackageDescription
import Foundation
let package = Package(
    name: "MacPin",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MacPin", type: .dynamic, targets: ["MacPin"]),
        .executable(name: "MacPin_static", targets: ["MacPin_static"]),
        .executable(name: "MacPin_stub", targets: ["MacPin_stub"]),
        .executable(name: "iconify", targets: ["iconify"]),
    ],
    dependencies: [
        .package(path: "modules/Linenoise"),
        .package(path: "modules/UTIKit"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
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
        .executableTarget(
            name: "iconify",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Tools/iconify",
            swiftSettings: [
                //.swiftLanguageMode(.v5)
            ]
        ),
        .target(name: "MacPin",
            dependencies: [
                "WebKitPrivates",
                "JavaScriptCorePrivates",
                "ViewPrivates",
                "UserNotificationPrivates",
                "Linenoise",
                "UTIKit",
            ],
            path: "Sources/MacPinOSX",
            swiftSettings: [
                //.swiftLanguageMode(.v5),
                //.interoperabilityMode(.Cxx)
            ]
        ),
        .executableTarget(
            name: "MacPin_static",
            dependencies: [
                .target(name: "MacPin")
            ],
            swiftSettings: [
                //.swiftLanguageMode(.v5),
                //.interoperabilityMode(.Cxx)
            ]
        ),
        .executableTarget(
            name: "MacPin_stub",
            dependencies: [],
            swiftSettings: [
                //.swiftLanguageMode(.v5),
                //.interoperabilityMode(.Cxx)
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path:@loader_path/../Frameworks"])
            ]
        )
    ])
}
