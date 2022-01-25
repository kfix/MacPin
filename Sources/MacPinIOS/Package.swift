// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "MacPin",
    platforms: [.iOS(.v13)],
    products: [
        .executable(name: "MacPin", targets: ["MacPin"]),
    ],
    dependencies: [
        .package(path: "../../modules/Linenoise"),
        .package(path: "../../modules/UTIKit"),
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
                "Package.swift",
                "./modules"
            ]
        ),
    ]
)
