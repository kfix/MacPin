/*
 * https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/WebKitAvailability.h
 *
 * Copyright (C) 2008, 2009, 2010, 2014 Apple Inc. All Rights Reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef __WebKitAvailabilityP__
#define __WebKitAvailabilityP__

#ifndef JSC_FRAMEWORK_HEADER_POSTPROCESSING_ENABLED
// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/postprocess-headers.sh

// http://clang.llvm.org/docs/AttributeReference.html#availability
#import <Availability.h>
#import <AvailabilityMacros.h>
#import <CoreFoundation/CoreFoundation.h>

// Use zero since it will be less than any possible version number.
#define JSC_MAC_VERSION_TBA 0
#define JSC_IOS_VERSION_TBA 0
#define JSC_API_AVAILABLE(...)
#define JSC_CLASS_AVAILABLE(...) __attribute__((visibility("default"))) JSC_API_AVAILABLE(__VA_ARGS__)
// API_AVAILABLE

#endif
#endif /* __WebKitAvailabilityP__ */

#ifdef __OBJC__
#import <Foundation/Foundation.h>

#if __has_feature(assume_nonnull)

#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#endif

#ifndef NS_ASSUME_NONNULL_END
#define NS_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#endif

#endif
#endif /* __OBJC__ */
