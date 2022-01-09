// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "WebKitPrivates",
    products: [
        .library(name: "WebKitPrivates", targets: ["WebKitPrivates"]),
    ],
    targets: [
        .systemLibrary(
            name: "WebKitPrivates",
            path: "./" // where the modulemap lives
        )
    ]
)
