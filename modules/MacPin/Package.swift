// swift-tools-version:5.4
import PackageDescription

var excludeds = ["mainsub.swift"]
#if os(macOS)
let osdir = "./_macos"
excludeds.append("_macos/appstub.swift")
excludeds.append("_ios")
#elseif os(iOS)
let osdir = "./_ios"
excludeds.append("_macos")
#endif

let package = Package(
	name: "MacPin",
    //platforms: [.iOS(.v13),.macOS(.v10_15)],
    // whines about a lot of unguarded calls to 10.15.4 apis
    platforms: [.iOS(.v13),.macOS(.v11)],
    products: [
        .library(name: "MacPin", type: .dynamic, targets: ["MacPin"]),
        .executable(name: "MacPinApp_static", targets: ["MacPinApp_static"]),
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
        // somehow have a target that makes libMacPin.dylib into a .framework
        .executableTarget(
            name: "MacPinApp_static",
            dependencies: ["MacPin"],
            path: "./",
            sources: ["mainsub.swift"]
            // resources: An explicit list of resources files.
        ),
        .executableTarget(
            name: "MacPinApp_osx",
            dependencies: [],
            path: osdir,
            sources: ["appstub.swift"],
            // resources: An explicit list of resources files.
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path:@loader_path/../Frameworks"])
            ]
        ),

    ]
)

#if os(macOS)
package.products.append(
    .executable(name: "MacPinApp_osx", targets: ["MacPinApp_osx"])
)
#endif
