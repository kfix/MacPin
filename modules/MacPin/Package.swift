// swift-tools-version:5.4
import PackageDescription

var excludeds = [] as [String]
#if os(macOS)
excludeds.append("_ios")
let osdir = "./_macos"
#elseif os(iOS)
excludeds.append("_macos")
let osdir = "./_ios"
#endif
excludeds.append("_ios/main.swift")
excludeds.append("_macos/main.swift")

let package = Package(
	name: "MacPin",
    //platforms: [.iOS(.v13),.macOS(.v10_15)],
    // whines about a lot of unguarded calls to 10.15.4 apis
    platforms: [.iOS(.v13),.macOS(.v11)],
    products: [
        .library(name: "MacPin", targets: ["MacPin"]),
        .executable(name: "MacPinApp", targets: ["MacPinApp"]),
    ],
    dependencies: [
		.package(path: "../WebKitPrivates"),
		.package(path: "../ViewPrivates"),
		.package(path: "../UserNotificationPrivates"),
		.package(path: "../JavaScriptCorePrivates"),
		.package(path: "../Linenoise"),
		.package(path: "../UTIKit"),
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
            path: "./",
            exclude: excludeds
        ),
        .executableTarget(
            name: "MacPinApp",
            dependencies: [
                "MacPin"
            ],
            path: osdir,
            sources: ["main.swift"]
            // resources: An explicit list of resources files.
        ),
    ]
)
