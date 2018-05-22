/*
 * https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h
 * Copyright (C) 2014 Apple Inc. All rights reserved.
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

#import <WebKit/WKUIDelegate.h>

#if WK_API_ENABLED

#import <WebKit/WKSecurityOrigin.h>
#import "_WKActivatedElementInfo.h"

#ifdef STP
#if 101100 >= __MAC_OS_X_VERSION_MAX_ALLOWED
//#import <WebKit/WKOpenPanelParameters.h>
#import "WKOpenPanelParameters.h"
#endif
#endif

@class UIScrollView;
@class UIViewController;
@class _WKContextMenuElementInfo;
@class _WKActivatedElementInfo;
@class _WKElementAction;
@class _WKFrameHandle;

@protocol WKUIDelegatePrivate <WKUIDelegate>

struct UIEdgeInsets;

@optional

// FIXME: This should be handled by the WKWebsiteDataStore delegate.
- (void)_webView:(WKWebView *)webView decideDatabaseQuotaForSecurityOrigin:(WKSecurityOrigin *)securityOrigin currentQuota:(unsigned long long)currentQuota currentOriginUsage:(unsigned long long)currentOriginUsage currentDatabaseUsage:(unsigned long long)currentUsage expectedUsage:(unsigned long long)expectedUsage decisionHandler:(void (^)(unsigned long long newQuota))decisionHandler;

// FIXME: This should be handled by the WKWebsiteDataStore delegate.
- (void)_webView:(WKWebView *)webView decideWebApplicationCacheQuotaForSecurityOrigin:(WKSecurityOrigin *)securityOrigin currentQuota:(unsigned long long)currentQuota totalBytesNeeded:(unsigned long long)totalBytesNeeded decisionHandler:(void (^)(unsigned long long newQuota))decisionHandler;

- (void)_webView:(WKWebView *)webView printFrame:(_WKFrameHandle *)frame;

- (void)_webViewClose:(WKWebView *)webView;
- (void)_webViewFullscreenMayReturnToInline:(WKWebView *)webView;
- (void)_webViewDidEnterFullscreen:(WKWebView *)webView WK2_AVAILABLE(10_11, 8_3);
- (void)_webViewDidExitFullscreen:(WKWebView *)webView WK2_AVAILABLE(10_11, 8_3);

- (void)_webView:(WKWebView *)webView imageOrMediaDocumentSizeChanged:(CGSize)size WK2_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);
- (NSDictionary *)_dataDetectionContextForWebView:(WKWebView *)webView WK2_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);
#if TARGET_OS_IPHONE
- (BOOL)_webView:(WKWebView *)webView shouldIncludeAppLinkActionsForElement:(_WKActivatedElementInfo *)element WK2_AVAILABLE(NA, 9_0);
- (NSArray *)_webView:(WKWebView *)webView actionsForElement:(_WKActivatedElementInfo *)element defaultActions:(WK_ARRAY(_WKElementAction *) *)defaultActions;
- (void)_webView:(WKWebView *)webView didNotHandleTapAsClickAtPoint:(CGPoint)point;
- (BOOL)_webView:(WKWebView *)webView shouldRequestGeolocationAuthorizationForURL:(NSURL *)url isMainFrame:(BOOL)isMainFrame mainFrameURL:(NSURL *)mainFrameURL;
- (UIViewController *)_webView:(WKWebView *)webView previewViewControllerForURL:(NSURL *)url WK2_AVAILABLE(NA, 9_0);
- (void)_webView:(WKWebView *)webView commitPreviewedViewController:(UIViewController *)previewedViewController WK2_AVAILABLE(NA, 9_0);
- (void)_webView:(WKWebView *)webView willPreviewImageWithURL:(NSURL *)imageURL WK2_AVAILABLE(NA, 9_0);
- (void)_webView:(WKWebView *)webView commitPreviewedImageWithURL:(NSURL *)imageURL WK2_AVAILABLE(NA, 9_0);
- (void)_webView:(WKWebView *)webView didDismissPreviewViewController:(UIViewController *)previewedViewController committing:(BOOL)committing WK2_AVAILABLE(NA, 9_0);
- (void)_webView:(WKWebView *)webView didDismissPreviewViewController:(UIViewController *)previewedViewController WK2_AVAILABLE(NA, 9_0);
- (BOOL)_webView:(WKWebView *)webView showCustomSheetForElement:(_WKActivatedElementInfo *)element WK2_AVAILABLE(NA, WK_IOS_TBA);
- (void)_webView:(WKWebView *)webView alternateActionForURL:(NSURL *)url WK2_AVAILABLE(NA, WK_IOS_TBA);
- (NSArray *)_attachmentListForWebView:(WKWebView *)webView WK2_AVAILABLE(NA, WK_IOS_TBA);
- (NSUInteger)_webView:(WKWebView *)webView indexIntoAttachmentListForElement:(_WKActivatedElementInfo *)element WK2_AVAILABLE(NA, WK_IOS_TBA);
- (UIEdgeInsets)_webView:(WKWebView *)webView finalObscuredInsetsForScrollView:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset WK2_AVAILABLE(NA, 9_0);
- (UIViewController *)_webView:(WKWebView *)webView previewViewControllerForURL:(NSURL *)url defaultActions:(WK_ARRAY(_WKElementAction *) *)actions elementInfo:(_WKActivatedElementInfo *)elementInfo WK2_AVAILABLE(NA, 9_0);
- (UIViewController *)_webView:(WKWebView *)webView previewViewControllerForAnimatedImageAtURL:(NSURL *)url defaultActions:(WK_ARRAY(_WKElementAction *) *)actions elementInfo:(_WKActivatedElementInfo *)elementInfo imageSize:(CGSize)imageSize WK2_AVAILABLE(NA, 9_0);
- (UIViewController *)_presentingViewControllerForWebView:(WKWebView *)webView WK2_AVAILABLE(NA, WK_IOS_TBA);
#else
- (NSMenu *)_webView:(WKWebView *)webView contextMenu:(NSMenu *)menu forElement:(_WKContextMenuElementInfo *)element WK_API_AVAILABLE(macosx(10.12));
- (NSMenu *)_webView:(WKWebView *)webView contextMenu:(NSMenu *)menu forElement:(_WKContextMenuElementInfo *)element userInfo:(id <NSSecureCoding>)userInfo WK_API_AVAILABLE(macosx(10.12));
- (void)_webView:(WKWebView *)webView getContextMenuFromProposedMenu:(NSMenu *)menu forElement:(_WKContextMenuElementInfo *)element userInfo:(id <NSSecureCoding>)userInfo completionHandler:(void (^)(NSMenu *))completionHandler WK_API_AVAILABLE(macosx(WK_MAC_TBA));
- (void)_showWebView:(WKWebView *)webView WK_API_AVAILABLE(macosx(10.13.4));
- (void)_focusWebView:(WKWebView *)webView WK_API_AVAILABLE(macosx(10.13.4));
- (void)_unfocusWebView:(WKWebView *)webView WK_API_AVAILABLE(macosx(10.13.4));
- (void)_webViewDidScroll:(WKWebView *)webView WK_API_AVAILABLE(macosx(10.13.4));
- (void)_webViewRunModal:(WKWebView *)webView WK_API_AVAILABLE(macosx(10.13.4));
//- (void)_webView:(WKWebView *)webView takeFocus:(_WKFocusDirection)direction WK_API_AVAILABLE(macosx(10.13.4));
- (void)_webView:(WKWebView *)webView didNotHandleWheelEvent:(NSEvent *)event WK_API_AVAILABLE(macosx(10.13.4));

- (void)_webView:(WKWebView *)webView saveDataToFile:(NSData *)data suggestedFilename:(NSString *)suggestedFilename mimeType:(NSString *)mimeType originatingURL:(NSURL *)url WK_API_AVAILABLE(macosx(10.13.4));
- (CGFloat)_webViewHeaderHeight:(WKWebView *)webView WK_API_AVAILABLE(macosx(10.13.4));
- (CGFloat)_webViewFooterHeight:(WKWebView *)webView WK_API_AVAILABLE(macosx(10.13.4));

- (void)_webView:(WKWebView *)webView drawHeaderInRect:(CGRect)rect forPageWithTitle:(NSString *)title URL:(NSURL *)url WK_API_AVAILABLE(macosx(10.13.4));
- (void)_webView:(WKWebView *)webView drawFooterInRect:(CGRect)rect forPageWithTitle:(NSString *)title URL:(NSURL *)url WK_API_AVAILABLE(macosx(10.13.4));
- (void)_webView:(WKWebView *)webView requestNotificationPermissionForSecurityOrigin:(WKSecurityOrigin *)securityOrigin decisionHandler:(void (^)(BOOL))decisionHandler WK_API_AVAILABLE(macosx(10.13.4));
#endif // !TARGET_OS_IPHONE


- (void)_webView:(WKWebView *)webView requestUserMediaAuthorizationForDevices:(_WKCaptureDevices)devices url:(NSURL *)url mainFrameURL:(NSURL *)mainFrameURL decisionHandler:(void (^)(BOOL authorized))decisionHandler WK_API_AVAILABLE(macosx(10.13), ios(11.0));
- (void)_webView:(WKWebView *)webView checkUserMediaPermissionForURL:(NSURL *)url mainFrameURL:(NSURL *)mainFrameURL frameIdentifier:(NSUInteger)frameIdentifier decisionHandler:(void (^)(NSString *salt, BOOL authorized))decisionHandler WK_API_AVAILABLE(macosx(10.12.3), ios(10.3));
- (void)_webView:(WKWebView *)webView mediaCaptureStateDidChange:(_WKMediaCaptureState)state WK_API_AVAILABLE(macosx(10.13), ios(11.0));

- (void)_webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures completionHandler:(void (^)(WKWebView *webView))completionHandler WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));

- (void)_webView:(WKWebView *)webView runBeforeUnloadConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));

- (void)_webView:(WKWebView *)webView requestGeolocationPermissionForFrame:(WKFrameInfo *)frame decisionHandler:(void (^)(BOOL allowed))decisionHandler WK_API_AVAILABLE(macosx(10.13.4), ios(11.3));

- (void)_webView:(WKWebView *)webView editorStateDidChange:(NSDictionary *)editorState WK_API_AVAILABLE(macosx(10.13.4), ios(11.3));

// - (void)_webView:(WKWebView *)webView didRemoveAttachment:(_WKAttachment *)attachment WK_API_AVAILABLE(macosx(10.13.4), ios(11.3));
// - (void)_webView:(WKWebView *)webView didInsertAttachment:(_WKAttachment *)attachment WK_API_AVAILABLE(macosx(10.13.4), ios(11.3));
// - (void)_webView:(WKWebView *)webView didInsertAttachment:(_WKAttachment *)attachment withSource:(NSString *)source WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));

@end

#endif // WK_API_ENABLED
