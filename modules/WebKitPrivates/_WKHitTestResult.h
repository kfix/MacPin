/*
 * https://github.com/WebKit/webkit/blob/main/Source/WebKit/Shared/API/Cocoa/_WKHitTestResult.h
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

// https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/WeakLinking.html#//apple_ref/doc/uid/20002378-106633-CJBGFCAC
//you're the weakest link... goodbye!
// `nm build//macosx-x86_64-apple-macosx10.11/exec/MacPin | grep _OBJC_CLASS_\$__WK` still sez its there

WK_CLASS_AVAILABLE(macosx(10.12))
__attribute__((weak_import))
@interface _WKHitTestResult : NSObject <NSCopying>

@property (nonatomic, readonly, copy) NSURL *absoluteImageURL;
@property (nonatomic, readonly, copy) NSURL *absolutePDFURL;
@property (nonatomic, readonly, copy) NSURL *absoluteLinkURL;
@property (nonatomic, readonly, copy) NSURL *absoluteMediaURL;

@property (nonatomic, readonly, copy) NSString *linkLabel;
@property (nonatomic, readonly, copy) NSString *linkTitle;
@property (nonatomic, readonly, copy) NSString *lookupText;

@property (nonatomic, readonly, getter=isContentEditable) BOOL contentEditable;

@property (nonatomic, readonly) CGRect elementBoundingBox;

@end
