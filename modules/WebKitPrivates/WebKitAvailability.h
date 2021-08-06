/*
 * https://github.com/WebKit/webkit/blob/main/Source/WebKit/Shared/API/Cocoa/WKFoundation.h
 * /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/WebKit.framework/Versions/A/Headers/WKFoundation.h.tmp
 * /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/WebKit.framework/Versions/A/Headers/WKFoundation.h
 *
 * Copyright (C) 2013 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Availability.h>
// /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/Availability.h
// Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/AvailabilityInternal.h
#import <TargetConditionals.h>
// /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/TargetConditionals.h

#import <Foundation/Foundation.h>
// for NS_ASSUME_NONNULL_*

#ifdef __cplusplus
#define WK_EXTERN extern "C" __attribute__((visibility ("default")))
#else
#define WK_EXTERN extern __attribute__((visibility ("default")))
#endif

#ifndef WK_FRAMEWORK_HEADER_POSTPROCESSING_ENABLED

// http://clang.llvm.org/docs/AttributeReference.html#availability
#define WK_API_AVAILABLE(...)
#define WK_CLASS_AVAILABLE(...) __attribute__((visibility("default"))) WK_API_AVAILABLE(__VA_ARGS__)
#define WK_API_DEPRECATED(_message, ...) __attribute__((deprecated(_message)))
#define WK_API_DEPRECATED_WITH_REPLACEMENT(_replacement, ...) __attribute__((deprecated("use " #_replacement)))
#define WK_CLASS_DEPRECATED_WITH_REPLACEMENT(_replacement, ...) __attribute__((visibility("default"))) __attribute__((deprecated("use " #_replacement)))

#endif
