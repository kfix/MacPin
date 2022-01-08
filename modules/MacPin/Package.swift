// swift-tools-version:5.3
import PackageDescription

var excludeds = [] as [String]
#if os(macOS)
excludeds.append("_ios")
#elseif os(iOS)
excludeds.append("_macos")
#endif

let package = Package(
	name: "MacPin",
    platforms: [.iOS(.v13),.macOS(.v10_15)],
    products: [
        .library(name: "MacPin", targets: ["MacPin"]),
        .executable(name: "MacPin", targets: ["MacPin"]),
    ],
    dependencies: [
		.package(path: "../WebKitPrivates"),
		.package(path: "../ViewPrivates"),
		.package(path: "../UserNotificationPrivates"),
		.package(path: "../JavaScriptCorePrivates"),
		// Linenoise
		// UTIKit
    ],
    targets: [
        .target(
            name: "MacPin",
            dependencies: [
                "WebKitPrivates",
            ],
            path: "./",
            exclude: excludeds
        ),
    ]
)
