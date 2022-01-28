import Foundation
import Darwin
func warn(_ msg: String = String(), function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) {
    FileHandle.standardError.write((msg + "\n").data(using: String.Encoding.utf8)!)
}

// Idearrrs:
// https://github.com/raphaelhanneken/iconizer
// https://github.com/raphaelhanneken/iconizer/tree/master/Iconizer/Models

enum IconIdiom {
    case mac
    case universal
}

struct IconOptions {
    var idiom: IconIdiom
    var scaleUp: Bool
    var basename: String
    var sizes: [Int: String]
    var scales: Array<Int>
}

@main
class Iconify {
    // https://developer.apple.com/library/mac/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html#//apple_ref/doc/uid/TP40012302-CH7-SW4i
    let iconsetOpts = IconOptions(
        idiom: .mac,
        scaleUp: true,
        basename: "icon_",
        sizes: [
            16: "16x16",
            32: "32x32",
            128: "128x128",
            256: "256x256",
            512: "512x512"
        ],
        scales: [1, 2]
    )

    // https://developer.apple.com/library/ios/recipes/xcode_help-image_catalog-1.0/Recipe.html
    // https://developer.apple.com/library/ios/documentation/UserExperience/Conceptual/MobileHIG/IconMatrix.html
    let appIconsetOpts = IconOptions(
        idiom: .universal,
        scaleUp: true,
        basename: "Icon-",
        sizes: [ // https://developer.apple.com/library/ios/qa/qa1686/_index.html
            // the TN says filenames don't matter but Xcode and actool disagree
            25: "Small-50",
            29: "Small",
            40: "Small-40",
            60: "60",
            76: "76"
            //512: 'iTunesArtwork' // needs to be this with no basename or extension
        ],
        scales: [1, 2, 3]
    )

    var imagesetOpts = IconOptions(
        idiom: .universal,
        scaleUp: false,
        basename: "image", //doesn't matter
        sizes: [:],
        scales: []
    )

    static func main() {
        if CommandLine.arguments.count < 2 {
            warn("Usage:\n\t \(#file) source.png output.xcassets IconSet|AppIcon|imageset")
            exit(1)
        }
        var args = CommandLine.arguments
        args = args.filter({ $0 != #file }) //drop the script file
        warn("starting \(#file): \(args)")
        for (idx, arg) in args.enumerated() {
            warn("arg[\(idx)] => \(arg)")
        }
        exit(1)
    }
}
// vim: filetype=swift
