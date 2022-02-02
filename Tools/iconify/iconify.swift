import ArgumentParser
import Cocoa
import Foundation

func warn(_ msg: String = String(), function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) {
    FileHandle.standardError.write((msg + "\n").data(using: String.Encoding.utf8)!)
}

extension String {
    var fileURL: URL {
        return URL(fileURLWithPath: self)
    }
    var pathExtension: String {
        return fileURL.pathExtension
    }
    var lastPathComponent: String {
        return fileURL.lastPathComponent
    }
    var basename: String {
        return fileURL.deletingPathExtension().lastPathComponent
    }
}

extension Dictionary {
    var jsonData: Data? {
        return try? JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted])
    }

    func toJSONString() -> String? {
        if let jsonData = jsonData {
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        }

        return nil
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

// Idearrrs:
// https://github.com/raphaelhanneken/iconizer
// https://github.com/raphaelhanneken/iconizer/tree/master/Iconizer/Models

enum IconIdiom: String {
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

enum OutputType: String, EnumerableFlag {
    case appiconset, iconset, imageset
}

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

func setScalesFromImageSize(src: NSImage, options: inout IconOptions) {
    // find the scales that can be evenly-derived from the source image's nativeSize
    let nativeSize = src.size.width
    for scale in [3, 2, 1] {
        if ((nativeSize.truncatingRemainder(dividingBy: CGFloat(scale))) == 0) {
            let pts = Int(nativeSize / CGFloat(scale))
            options.sizes[pts] = "\(pts)"
            for i in 1...scale { options.scales.append(i) }
            break
        }
    }
}

func imageExplode(src: NSImage, outdir: String, options: IconOptions) -> Array<[String:String]> {
    warn("generating \(outdir)")
    // mkdir outdir
    try? FileManager.default.createDirectory(atPath: outdir, withIntermediateDirectories: true)
    var images: Array<[String:String]> = []
    for size in options.sizes.keys.sorted() {
        for scale in options.scales {
            let pxs = CGFloat(size * scale)
            if !options.scaleUp && (src.size.width < pxs) {
                continue
            }
            // do rescaling
            var imageName = options.basename
            let sizeVal = options.sizes[size] ?? "\(size)x\(size)"
            imageName.append(sizeVal)
            if (scale > 1) {
                imageName.append("@\(scale)x")
            }
            let imagePath = outdir + "/" + imageName + ".png"
            warn("\(size) @ \(scale)x => \(imageName) => \(imagePath)")
            let newImage = NSImage(size: NSMakeSize(pxs, pxs))
            newImage.lockFocus()
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.imageInterpolation = .high
            src.draw(
                in: NSMakeRect(0, 0, pxs, pxs),
                from: NSZeroRect,
                operation: .sourceOver,
                fraction: 1.0
            )
            newImage.unlockFocus()
            NSGraphicsContext.restoreGraphicsState()
            guard let newTiff = newImage.tiffRepresentation, let bmp = NSBitmapImageRep(data: newTiff) else { continue }
            bmp.hasAlpha = true
            guard let data = bmp.representation(using: NSBitmapImageRep.FileType.png, properties: [.compressionFactor: 0.85]) else { continue }
            try? data.write(to: imagePath.fileURL)
            images.append([
                "filename": imagePath.lastPathComponent,
                "idiom": options.idiom.rawValue,
                "size": "\(size)x\(size)",
                "scale": "\(scale)x"
            ])
        }
    }
    return images
}

@main
struct Iconify: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "generate an .icns, .iconset, .xcasset, and .car from a single big bitmap icon.")

    @Flag(help: "type of icons to be generated in the xcassets dir")
    var outputType: OutputType
    // default to imageset

    @Argument(help: "path of the source .png file")
    var sourcePath: String

    @Argument(help: "path of the output .xcassets directory")
    var xcassetPath: String
    // default to sourcePath - ext + .xcassets

    mutating func run() throws {
        let iconName = sourcePath.basename
        guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
            throw RuntimeError("\(sourcePath) is unparseable as an NSImage")
        }
        var outputPath: String
        var iconOptions: IconOptions
        switch (outputType) {
            case .appiconset:
                outputPath = "\(xcassetPath)/AppIcon.appiconset"
                iconOptions = appIconsetOpts
            case .iconset:
                outputPath = "\(xcassetPath)/Icon.iconset"
                iconOptions = iconsetOpts
            case .imageset:
                outputPath = "\(xcassetPath)/\(iconName).imageset"
                iconOptions = imagesetOpts
                setScalesFromImageSize(src: sourceImage, options: &iconOptions)
        }
        let imagesinfo = imageExplode(src: sourceImage, outdir: outputPath, options: iconOptions)

        switch (outputType) {
            case .iconset:
                // OSX icon, needs nothing
                break;
            case .appiconset, .imageset:
                // write imagesinfo
                var info: [String:Any] = [
                    "info": [
                        "version": 1,
                        "author": "iconify"
                    ],
                ]
                info["images"] = imagesinfo
                let manifest = "\(outputPath)/Contents.json"
                guard let jsonString = info.toJSONString() else {
                    throw RuntimeError("could not serialize JSON for \(manifest)")
                }
                //warn("============= \(manifest) ==========\n\(jsonString)")
                try? jsonString.write(to: manifest.fileURL, atomically: true, encoding: String.Encoding.utf8)
        }
    }
}
// vim: filetype=swift
