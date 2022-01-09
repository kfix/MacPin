// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "UserNotificationPrivates",
    products: [
        .library(name: "UserNotificationPrivates", targets: ["UserNotificationPrivates"]),
    ],
    targets: [
        .systemLibrary(
            name: "UserNotificationPrivates",
            path: "./" // where the modulemap lives
        )
    ]
)
