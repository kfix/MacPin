/*
 * https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/C/WKContextPrivate.h
 *
 * Copyright (C) 2010, 2012 Apple Inc. All rights reserved.
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

#ifndef WKContextPrivate_h
#define WKContextPrivate_h

#import "WKBase.h"
#import "WKContext.h"

#ifdef __cplusplus
extern "C" {
#endif

struct WKContextStatistics {
    unsigned wkViewCount;
    unsigned wkPageCount;
    unsigned wkFrameCount;
};
typedef struct WKContextStatistics WKContextStatistics;

WK_EXPORT void WKContextGetGlobalStatistics(WKContextStatistics* statistics);

WK_EXPORT void WKContextSetAdditionalPluginsDirectory(WKContextRef context, WKStringRef pluginsDirectory);

WK_EXPORT void WKContextRegisterURLSchemeAsEmptyDocument(WKContextRef context, WKStringRef urlScheme);

WK_EXPORT void WKContextSetAlwaysUsesComplexTextCodePath(WKContextRef context, bool alwaysUseComplexTextCodePath);

WK_EXPORT void WKContextSetShouldUseFontSmoothing(WKContextRef context, bool useFontSmoothing);

WK_EXPORT void WKContextRegisterURLSchemeAsSecure(WKContextRef context, WKStringRef urlScheme);

WK_EXPORT void WKContextRegisterURLSchemeAsBypassingContentSecurityPolicy(WKContextRef context, WKStringRef urlScheme);

WK_EXPORT void WKContextRegisterURLSchemeAsCachePartitioned(WKContextRef context, WKStringRef urlScheme);

WK_EXPORT void WKContextSetDomainRelaxationForbiddenForURLScheme(WKContextRef context, WKStringRef urlScheme);

WK_EXPORT void WKContextSetCanHandleHTTPSServerTrustEvaluation(WKContextRef context, bool value) WK_C_API_DEPRECATED;

WK_EXPORT void WKContextSetDiskCacheSpeculativeValidationEnabled(WKContextRef context, bool value) WK_C_API_DEPRECATED;

WK_EXPORT void WKContextSetIconDatabasePath(WKContextRef context, WKStringRef iconDatabasePath);

WK_EXPORT void WKContextAllowSpecificHTTPSCertificateForHost(WKContextRef context, WKCertificateInfoRef certificate, WKStringRef host);

// FIXME: This is a workaround for testing purposes only and should be removed once a better
// solution has been found for testing.
WK_EXPORT void WKContextDisableProcessTermination(WKContextRef context);
WK_EXPORT void WKContextEnableProcessTermination(WKContextRef context);

WK_EXPORT void WKContextSetHTTPPipeliningEnabled(WKContextRef context, bool enabled);

WK_EXPORT void WKContextWarmInitialProcess(WKContextRef context);

// FIXME: This function is temporary and useful during the development of the NetworkProcess feature.
// At some point it should be removed.
WK_EXPORT void WKContextSetUsesNetworkProcess(WKContextRef, bool);

// Test only. Should be called before any secondary processes are started.
WK_EXPORT void WKContextUseTestingNetworkSession(WKContextRef context);

// Test only. Should be called before running a test.
WK_EXPORT void WKContextClearCachedCredentials(WKContextRef context);

typedef void (*WKContextInvalidMessageFunction)(WKStringRef messageName);
WK_EXPORT void WKContextSetInvalidMessageFunction(WKContextInvalidMessageFunction invalidMessageFunction);
    
WK_EXPORT void WKContextSetMemoryCacheDisabled(WKContextRef, bool disabled);

WK_EXPORT void WKContextSetFontWhitelist(WKContextRef, WKArrayRef);

#ifdef __cplusplus
}
#endif

#endif /* WKContextPrivate_h */
