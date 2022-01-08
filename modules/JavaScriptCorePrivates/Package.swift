// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "JavaScriptCorePrivates",
    products: [
        .library(name: "JavaScriptCorePrivates", targets: ["JavaScriptCorePrivates"]),
    ],
    targets: [
        .systemLibrary(
            name: "JavaScriptCorePrivates",
            path: "./" // where the modulemap lives
        )
    ]
)
