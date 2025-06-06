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

#import "MSIDNonceTokenRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDAuthority.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDNonceHttpRequest.h"
#import "MSIDCachedNonce.h"

const static NSUInteger kMSIDNonceLifetimeInSeconds = 180;
@implementation MSIDNonceTokenRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
{
    self = [super init];
    if (self)
    {
        _requestParameters = parameters;
    }
    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDNonceRequestCompletion)completionBlock
{
    MSIDCachedNonce *cachedNonce = [self.class getCachedNonceForKey:self.requestParameters.authority.environment];
    if (cachedNonce)
    {
        completionBlock(cachedNonce.nonce, nil);
        return;
    }

    if (self.requestParameters.authority.metadata.tokenEndpoint)
    {
        [self executeNetworkRequestWithCompletion:completionBlock];
        return;
    }
    
    [self.requestParameters.authority resolveAndValidate:YES
                                       userPrincipalName:_requestParameters.accountIdentifier.displayableId
                                                 context:_requestParameters
                                         completionBlock:^(NSURL __unused *openIdConfigurationEndpoint, BOOL __unused validated, NSError *error)
    {
        if (error)
        {
            completionBlock(nil, error);
            return;
        }
        
        [self.requestParameters.authority loadOpenIdMetadataWithContext:self.requestParameters
                                                        completionBlock:^(__unused MSIDOpenIdProviderMetadata *metadata, NSError *openIdError)
         {
             
             if (openIdError)
             {
                 completionBlock(nil, openIdError);
                 return;
             }
             
             [self executeNetworkRequestWithCompletion:completionBlock];
         }];
    }];
}

- (void)executeNetworkRequestWithCompletion:(nonnull MSIDNonceRequestCompletion)completionBlock
{
    MSIDNonceHttpRequest *nonceRequest = [[MSIDNonceHttpRequest alloc] initWithTokenEndpoint:self.requestParameters.tokenEndpoint
                                                                                     context:self.requestParameters];
    [nonceRequest sendWithBlock:^(NSDictionary *response, NSError *error)
    {
        if (error)
        {
            if (completionBlock) completionBlock(nil, error);
            return;
        }
        
        if (![response isKindOfClass:[NSDictionary class]])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Unexpected nonce response received");
            NSError *nwError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidResponse, @"Unexpected nonce response", nil, nil, nil, nil, nil, YES);
            if (completionBlock) completionBlock(nil, nwError);
            return;
        }
        
        NSString *nonce = [response msidStringObjectForKey:@"Nonce"];
        
        if ([NSString msidIsStringNilOrBlank:nonce])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Didn't receive valid nonce in response");
            NSError *nwError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidResponse, @"Didn't receive valid nonce in response", nil, nil, nil, nil, nil, YES);
            if (completionBlock) completionBlock(nil, nwError);
            return;
        }
        
        [self.class cacheNonceForKey:self.requestParameters.authority.environment nonce:nonce];
        if (completionBlock)
        {
            completionBlock(nonce, nil);
        }
    }];
}

#pragma mark - Cache

+ (MSIDCache *)nonceCache
{
    static MSIDCache *k_nonceCache;
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        k_nonceCache = [MSIDCache new];
    });
    
    return k_nonceCache;
}

+ (nullable MSIDCachedNonce *)getCachedNonceForKey:(NSString *)key
{
    MSIDCache *cache = [self.class nonceCache];
    MSIDCachedNonce *cachedNonce = [cache objectForKey:key];
    if (cachedNonce)
    {
        NSTimeInterval ti = [[NSDate date] timeIntervalSinceDate:cachedNonce.cachedDate];
        if (ti > 0 && ti < kMSIDNonceLifetimeInSeconds)
        {
            return cachedNonce;
        }
    }
    
    return nil;
}

+ (BOOL)cacheNonceForKey:(NSString *)key nonce:(NSString *)nonce
{
    if (!nonce || !key)
    {
        return NO;
    }
    
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:nonce];
    [self.class.nonceCache setObject:cachedNonce forKey:key];
    return YES;
}
@end
