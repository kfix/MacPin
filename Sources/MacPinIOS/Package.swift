// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "MacPin",
    platforms: [.iOS(.v13)],
    products: [
        .executable(name: "MacPin", targets: ["MacPin"]),
    ],
    dependencies: [
        .package(path: "../../modules/WebKitPrivates"),
        .package(path: "../../modules/ViewPrivates"),
        .package(path: "../../modules/UserNotificationPrivates"),
        .package(path: "../../modules/JavaScriptCorePrivates"),
        .package(path: "../../modules/Linenoise"),
        .package(path: "../../modules/UTIKit"),
    ],
    targets: [
        .executableTarget(name: "MacPin",
            dependencies: [
                "WebKitPrivates",
                "JavaScriptCorePrivates",
                "ViewPrivates",
                "UserNotificationPrivates",
                "Linenoise",
                "UTIKit",
            ],
            path: "./",
            exclude: [
                "Package.swift"
            ]
        ),
    ]
)
