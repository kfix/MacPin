// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ViewPrivates",
    products: [
        .library(name: "ViewPrivates", targets: ["ViewPrivates"]),
    ],
    targets: [
        .systemLibrary(
            name: "ViewPrivates",
            path: "./" // where the modulemap lives
        )
    ]
)
