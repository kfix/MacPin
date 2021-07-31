/* https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKInputDelegate.h
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

@class WKWebView;
@protocol _WKFocusedElementInfo;
@protocol _WKFormInputSession;

@protocol _WKInputDelegate <NSObject>

@optional

- (void)_webView:(WKWebView *)webView didStartInputSession:(id <_WKFormInputSession>)inputSession;
- (void)_webView:(WKWebView *)webView willSubmitFormValues:(NSDictionary *)values userObject:(NSObject <NSSecureCoding> *)userObject submissionHandler:(void (^)(void))submissionHandler;

#if TARGET_OS_IPHONE
- (BOOL)_webView:(WKWebView *)webView focusShouldStartInputSession:(id <_WKFocusedElementInfo>)info;
- (void)_webView:(WKWebView *)webView accessoryViewCustomButtonTappedInFormInputSession:(id <_WKFormInputSession>)inputSession;
- (BOOL)_webView:(WKWebView *)webView hasSuggestionsForCurrentStringInInputSession:(id <_WKFormInputSession>)inputSession;
- (NSArray *)_webView:(WKWebView *)webView suggestionsForString:(NSString *)string inInputSession:(id <_WKFormInputSession>)inputSession;
#endif

@end
