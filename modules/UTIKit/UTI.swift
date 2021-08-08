//  The MIT License (MIT)
//
//  Copyright (c) 2015 Hiroki Kato
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.


import Foundation
#if os(iOS)
import MobileCoreServices
#endif

public struct UTI: CustomStringConvertible, CustomDebugStringConvertible, Equatable {

    public let utiString: String

    // MARK: - Initialize

    public init(_ utiString: String) {
        self.utiString = utiString
    }

    public init?(filenameExtension: String, conformingTo: UTI? = nil) {
        let conformingToUtiString: CFString? = conformingTo?.utiString as CFString?
        guard let rawUti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, filenameExtension as CFString, conformingToUtiString)?.takeRetainedValue() else { return nil }
        self.utiString = rawUti as String
    }

    public init?(mimeType: String, conformingTo: UTI? = nil) {
        let conformingToUtiString: CFString? = conformingTo?.utiString as CFString?
        guard let rawUti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, conformingToUtiString)?.takeRetainedValue() else { return nil }
        self.utiString = rawUti as String
    }

    #if os(macOS)
    public init?(pasteBoardType: String, conformingTo: UTI? = nil) {
        let conformingToUtiString: CFString? = conformingTo?.utiString as CFString?
        guard let rawUti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassNSPboardType, pasteBoardType as CFString, conformingToUtiString)?.takeRetainedValue() else { return nil }
        self.utiString = rawUti as String
    }

    public init?(OSType: String, conformingTo: UTI? = nil) {
        let conformingToUtiString: CFString? = conformingTo?.utiString as CFString?
        guard let rawUti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassOSType, OSType as CFString, conformingToUtiString)?.takeRetainedValue() else { return nil }
        self.utiString = rawUti as String
    }
    #endif

    // MARK: -

    private static func UTIs(for tagClass: String, tag: String, conformingTo: UTI?) -> [UTI] {
        let conformingToUTIString: CFString? = conformingTo?.utiString as CFString?
        guard let rawUTIs = UTTypeCreateAllIdentifiersForTag(tagClass as CFString, tag as CFString, conformingToUTIString)?.takeRetainedValue() else { return [] }
        return (rawUTIs as NSArray as? [String] ?? []).map { UTI($0) }
    }

    public static func UTIs(fromFilenameExtension filenameExtension: String, conformingTo: UTI? = nil) -> [UTI] {
        return UTIs(for: kUTTagClassFilenameExtension as String, tag: filenameExtension, conformingTo: conformingTo)
    }

    public static func UTIs(fromMimeType mimeType: String, conformingTo: UTI? = nil) -> [UTI] {
        return UTIs(for: kUTTagClassMIMEType as String, tag: mimeType, conformingTo: conformingTo)
    }

    #if os(macOS)
    public static func UTIs(fromPasteBoardType pasteBoardType: String, conformingTo: UTI? = nil) -> [UTI] {
        return UTIs(for: kUTTagClassNSPboardType as String, tag: pasteBoardType, conformingTo: conformingTo)
    }

    public static func UTIs(fromOTType OSType: String, conformingTo: UTI? = nil) -> [UTI] {
        return UTIs(for: kUTTagClassOSType as String, tag: OSType, conformingTo: conformingTo)
    }
    #endif

    // MARK: - Tags

    private func tag(withClass tagClass: String) -> String? {
        return UTTypeCopyPreferredTagWithClass(utiString as CFString, tagClass as CFString)?.takeRetainedValue() as String?
    }

    @available(macOS, introduced:10.10)
    @available(iOS, introduced:8.0)
    private func tags(withClass tagClass: String) -> [String] {
        guard let tags = UTTypeCopyAllTagsWithClass(utiString as CFString, tagClass as CFString)?.takeRetainedValue() else { return [] }
        return tags as NSArray as? [String] ?? []
    }

    public var filenameExtension: String? {
        return tag(withClass: kUTTagClassFilenameExtension as String)
    }

    @available(macOS, introduced:10.10)
    @available(iOS, introduced:8.0)
    public var filenameExtensions: [String] {
        return tags(withClass: kUTTagClassFilenameExtension as String)
    }

    public var mimeType: String? {
        return tag(withClass: kUTTagClassMIMEType as String)
    }

    @available(macOS, introduced:10.10)
    @available(iOS, introduced:8.0)
    public var mimeTypes: [String] {
        return tags(withClass: kUTTagClassMIMEType as String)
    }

    #if os(macOS)
    public var pasteBoardType: String? {
        return tag(withClass: kUTTagClassNSPboardType as String)
    }

    @available(macOS, introduced:10.10)
    public var pasteBoardTypes: [String] {
        return tags(withClass: kUTTagClassNSPboardType as String)
    }

    public var OSType: String? {
        return tag(withClass: kUTTagClassOSType as String)
    }

    @available(macOS, introduced:10.10)
    public var OSTypes: [String] {
        return tags(withClass: kUTTagClassOSType as String)
    }
    #endif

    // MARK: - Status

    @available(macOS, introduced:10.10)
    @available(iOS, introduced:8.0)
    public var isDeclared: Bool {
        return UTTypeIsDeclared(utiString as CFString)
    }

    @available(macOS, introduced:10.10)
    @available(iOS, introduced:8.0)
    public var isDynamic: Bool {
        return UTTypeIsDynamic(utiString as CFString)
    }

    // MARK: - Declaration

    public struct Declaration: CustomStringConvertible, CustomDebugStringConvertible {
        fileprivate let raw: [AnyHashable: Any]

        public var exportedTypeDeclarations: [Declaration] {
            return (raw[kUTExportedTypeDeclarationsKey as AnyHashable] as? [[AnyHashable: Any]] ?? []).map { Declaration(declaration: $0) }
        }

        public var importedTypeDeclarations: [Declaration] {
            return (raw[kUTImportedTypeDeclarationsKey as AnyHashable] as? [[AnyHashable: Any]] ?? []).map { Declaration(declaration: $0) }
        }

        public var identifier: String? {
            return raw[kUTTypeIdentifierKey as AnyHashable] as? String
        }

        public var tagSpecification: [AnyHashable: Any] {
            return raw[kUTTypeTagSpecificationKey as AnyHashable] as? [AnyHashable: Any] ?? [:]
        }

        public var conformsTo: [UTI] {
            switch raw[kUTTypeConformsToKey as AnyHashable] {
            case let array as [String]:
                return array.map { UTI($0) }
            case let string as String:
                return [ UTI(string) ]
            default:
                return []
            }
        }

        public var iconFile: String? {
            return raw[kUTTypeIconFileKey as AnyHashable] as? String
        }

        public var referenceUrl: URL? {
            if let reference = raw[kUTTypeReferenceURLKey as AnyHashable] as? String {
                return URL(string: reference)
            }
            return nil
        }

        public var version: String? {
            return raw[kUTTypeVersionKey as AnyHashable] as? String
        }

        init(declaration: [AnyHashable: Any]) {
            self.raw = declaration
        }

        public var description: String {
            return raw.description
        }

        public var debugDescription: String {
            return raw.debugDescription
        }

    }

    public var declaration: Declaration {
        return Declaration(declaration: UTTypeCopyDeclaration(self.utiString as CFString)?.takeRetainedValue() as! [AnyHashable: Any]? ?? [:])
    }

    public var declaringBundle: Bundle? {
        if let url = UTTypeCopyDeclaringBundleURL(utiString as CFString)?.takeRetainedValue() {
            return Bundle(url: url as URL)
        }
        return nil
    }

    public var iconFileUrl: URL? {
        if let iconFile = declaration.iconFile {
            return self.declaringBundle?.url(forResource: iconFile, withExtension: nil) ??
                   self.declaringBundle?.url(forResource: iconFile, withExtension: "icns")
        }
        return nil
    }

    // MARK: - Printable, DebugPrintable

    public var description: String {
        return UTTypeCopyDescription(utiString as CFString)?.takeRetainedValue() as String? ?? utiString
    }

    public var debugDescription: String {
        return utiString
    }

}

public func ==(lhs: UTI, rhs: UTI) -> Bool {
    return UTTypeEqual(lhs.utiString as CFString, rhs.utiString as CFString)
}

public func ~=(pattern: UTI, value: UTI) -> Bool {
    return UTTypeConformsTo(value.utiString as CFString, pattern.utiString as CFString)
}

// MARK: - Deprecated

public extension UTI {

    @available(*, unavailable, renamed: "utiString")
    var UTIString: String {
        return utiString
    }

    @available(*, unavailable, renamed: "init(filenameExtension:conformingTo:)")
    init?(filenameExtension: String, conformingToUTI: UTI? = nil) {
        self.init(filenameExtension: filenameExtension, conformingTo: conformingToUTI)
    }

    @available(*, unavailable, renamed: "init(mimeType:conformingTo:)")
    init?(MIMEType: String, conformingToUTI: UTI? = nil) {
        self.init(mimeType: MIMEType, conformingTo: conformingToUTI)
    }

    @available(*, unavailable, renamed: "UTIs(fromFilenameExtension:conformingTo:)")
    static func UTIsFromFilenameExtension(_ filenameExtension: String, conformingToUTI: UTI? = nil) -> [UTI] {
        return UTIs(fromFilenameExtension: filenameExtension, conformingTo: conformingToUTI)
    }

    @available(*, unavailable, renamed: "UTIs(fromMimeType:conformingTo:)")
    static func UTIsFromMIMEType(_ MIMEType: String, conformingToUTI: UTI? = nil) -> [UTI] {
        return UTIs(fromMimeType: MIMEType, conformingTo: conformingToUTI)
    }

    #if os(macOS)
    @available(*, unavailable, renamed: "init(pasteBoardType:conformingTo:)")
    init?(pasteBoardType: String, conformingToUTI: UTI? = nil) {
        self.init(pasteBoardType: pasteBoardType, conformingTo: conformingToUTI)
    }

    @available(*, unavailable, renamed: "init(OSType:conformingTo:)")
    init?(OSType: String, conformingToUTI: UTI? = nil) {
        self.init(OSType: OSType, conformingTo: conformingToUTI)
    }

    @available(*, unavailable, renamed: "UTIs(fromPasteBoardType:conformingTo:)")
    static func UTIsFromPasteBoardType(pasteBoardType: String, conformingToUTI: UTI? = nil) -> [UTI] {
        return UTIs(fromPasteBoardType: pasteBoardType, conformingTo: conformingToUTI)
    }

    @available(*, unavailable, renamed: "UTIs(fromOSType:conformingTo:)")
    static func UTIsFromOSType(OSType: String, conformingToUTI: UTI? = nil) -> [UTI] {
        return UTIs(fromOTType: OSType, conformingTo: conformingToUTI)
    }
    #endif

    @available(*, unavailable, renamed: "mimeType")
    var MIMEType: String? {
        return mimeType
    }

    @available(*, unavailable, renamed: "mimeTypes")
    var MIMETypes: [String] {
        return mimeTypes
    }

    @available(*, unavailable, renamed: "iconFileUrl")
    var iconFileURL: URL? {
        return iconFileUrl
    }

}

public extension UTI.Declaration {

    @available(*, unavailable, renamed: "referenceUrl")
    var referenceURL: URL? {
        return referenceUrl
    }

}
