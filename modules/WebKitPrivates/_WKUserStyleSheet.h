/*
	* https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKUserStyleSheet.h
 *
 * Copyright (C) 2015 Apple Inc. All rights reserved.
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

#import <WebKit/WKFoundation.h>


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class _WKUserContentWorld;

WK_CLASS_AVAILABLE(macosx(10.12), ios(10.0))
@interface _WKUserStyleSheet : NSObject <NSCopying>

@property (nonatomic, readonly, copy) NSString *source;

@property (nonatomic, readonly, copy) NSURL *baseURL;

@property (nonatomic, readonly, getter=isForMainFrameOnly) BOOL forMainFrameOnly;

- (instancetype)initWithSource:(NSString *)source forMainFrameOnly:(BOOL)forMainFrameOnly;
- (instancetype)initWithSource:(NSString *)source forMainFrameOnly:(BOOL)forMainFrameOnly legacyWhitelist:(WK_ARRAY(NSString *) *)legacyWhitelist legacyBlacklist:(WK_ARRAY(NSString *) *)legacyBlacklist userContentWorld:(_WKUserContentWorld *)userContentWorld;
- (instancetype)initWithSource:(NSString *)source forMainFrameOnly:(BOOL)forMainFrameOnly legacyWhitelist:(WK_ARRAY(NSString *) *)legacyWhitelist legacyBlacklist:(WK_ARRAY(NSString *) *)legacyBlacklist baseURL:(NSURL *)baseURL userContentWorld:(_WKUserContentWorld *)userContentWorld;

@end

NS_ASSUME_NONNULL_END

