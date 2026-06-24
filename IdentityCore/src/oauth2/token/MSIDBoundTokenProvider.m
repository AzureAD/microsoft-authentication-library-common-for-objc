//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDBoundTokenProvider.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDError.h"
#import "MSIDLogger+Internal.h"
#import "NSString+MSIDExtensions.h"

NSString *const MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX = @"[MSIDBoundTokenProvider]";

@implementation MSIDBoundTokenProvider

- (void)acquireBoundTokenWithRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                             context:(nullable id<MSIDRequestContext>)context
                     completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    if (!completionBlock) return;

    if (![self validateRequest:request context:context completionBlock:completionBlock])
    {
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"%@ Servicing GetToken request in-process (no SSO extension). clientId: %@",
                      MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, request.clientId);

    // Stub seam: the real silent-redemption / interactive-broker-flip orchestration is layered on top of
    // this provider. Returns the serialized browser-native-message response payload.
    NSString *responsePayload = [self stubResponsePayloadForRequest:request];

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"%@ In-process GetToken request completed.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);

    completionBlock(responsePayload, nil);
}

#pragma mark - Private

- (BOOL)validateRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                context:(nullable id<MSIDRequestContext>)context
        completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    if (!request)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter,
                                         @"A GetToken request is required.", nil, nil, nil,
                                         context.correlationId, nil, NO);
        completionBlock(nil, error);
        return NO;
    }

    if ([NSString msidIsStringNilOrBlank:request.clientId] ||
        [NSString msidIsStringNilOrBlank:request.redirectUri])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter,
                                         @"clientId and redirectUri are required to acquire a bound token.",
                                         nil, nil, nil, context.correlationId, nil, NO);
        completionBlock(nil, error);
        return NO;
    }

    return YES;
}

- (NSString *)stubResponsePayloadForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
{
    NSMutableDictionary *payload = [NSMutableDictionary new];
    payload[@"clientId"] = request.clientId ?: @"";
    payload[@"redirectUri"] = request.redirectUri ?: @"";
    payload[@"scope"] = request.scopes ?: @"";
    payload[@"servicedBy"] = @"MSIDBoundTokenProvider";
    payload[@"transport"] = @"in_proc_common_core";
    if (request.state)
    {
        payload[@"state"] = request.state;
    }

    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&serializationError];
    if (serializationError || !data)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@ Failed to serialize bound token payload: %@", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, serializationError);
        return @"{}";
    }

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
