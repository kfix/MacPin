# UTIKit

UTIKit is an UTI (Uniform Type Identifier) wrapper for Swift.

## Features

UTIKit is a full featured library including entire UTI functions.

- Convertibility
  - Filename extension
  - MIME type
  - OSType (OS X only)
  - Pasteboard type (OS X only)
- Equality
- Conformance
- and others…

## Usage

### Making from an UTI string

```swift
let jpeg = UTI("public.jpeg")
```

### Making from a filename extension

```swift
let jpeg = UTI(filenameExtension: "jpeg")
```

### Making from a MIME type

```swift
let jpeg = UTI(mimeType: "image/jpeg")
```

### Getting filename extensions or MIME types

```swift
UTI(mimeType: "image/jpeg").filenameExtensions // => ["jpeg", "jpg", "jpe"]

UTI(filenameExtension: "jpeg").mimeTypes // => ["image/jpeg"]
```

### Equality

```swift
UTI(mimeType: "image/jpeg") == UTI(filenameExtension: "jpeg") // => true
```

### Conformance

```swift
switch UTI(kUTTypeJPEG) {
case UTI(kUTTypeImage):
    print("JPEG is a kind of images")
default:
    fatalError("JPEG must be a image")
}
```

## Requirements

- Swift 3.0 or later
- iOS 8 or later
- OS X 10.10 or later

## Author

Hiroki Kato, mail@cockscomb.info

## License

UTIKit is available under the MIT license. See the LICENSE file for more info.
