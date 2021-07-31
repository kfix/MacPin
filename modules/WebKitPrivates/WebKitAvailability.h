/*
 * https://github.com/WebKit/webkit/blob/main/Source/WebKit/Shared/API/Cocoa/WKFoundation.h
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

#ifndef __WebKitFoundationP__
#define __WebKitFoundationP__

#import <Availability.h>
// /usr/include/AvailabilityInternal.h
// /usr/include/Availability.h
#import <TargetConditionals.h>

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

#if __has_feature(objc_generics) && (!defined(__MAC_OS_X_VERSION_MAX_ALLOWED) || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101100)

#define WK_ARRAY(_objectType) NSArray<_objectType>
#define WK_DICTIONARY(_keyType, _valueType) NSDictionary<_keyType, _valueType>
#define WK_SET(_objectType) NSSet<_objectType>

#else

#define WK_ARRAY(...) NSArray
#define WK_DICTIONARY(...) NSDictionary
#define WK_SET(...) NSSet

#endif

#ifndef __NSi_8_3
#define __NSi_8_3 introduced=8.3
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>

#ifdef NS_DESIGNATED_INITIALIZER
#define WK_DESIGNATED_INITIALIZER NS_DESIGNATED_INITIALIZER
#else
#define WK_DESIGNATED_INITIALIZER
#endif

#ifdef NS_UNAVAILABLE
#define WK_UNAVAILABLE NS_UNAVAILABLE
#else
#define WK_UNAVAILABLE
#endif

#if __has_feature(assume_nonnull)

#ifdef NS_ASSUME_NONNULL_BEGIN
#define WK_ASSUME_NONNULL_BEGIN NS_ASSUME_NONNULL_BEGIN
#else
#define WK_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#endif

#ifdef NS_ASSUME_NONNULL_END
#define WK_ASSUME_NONNULL_END NS_ASSUME_NONNULL_END
#else
#define WK_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#endif

#define WK_NULLABLE nullable
#define WK_NULL_UNSPECIFIED null_unspecified
#define WK_NULLABLE_SPECIFIER __nullable
#define WK_NULLABLE_PROPERTY nullable,

#else

#define WK_ASSUME_NONNULL_BEGIN
#define WK_ASSUME_NONNULL_END

#define WK_NULLABLE
#define WK_NULL_UNSPECIFIED
#define WK_NULLABLE_SPECIFIER
#define WK_NULLABLE_PROPERTY

#endif

#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED < 101000
typedef NSUInteger NSEventModifierFlags;
#endif

#endif

#endif

#endif /* __WebKitFoundationP__ */
