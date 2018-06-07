//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import "MSIDAuthorityResolving.h"
#import "MSIDCache.h"

@class MSIDOpenIdProviderMetadata;

typedef void(^MSIDOpenIdConfigurationInfoBlock)(MSIDOpenIdProviderMetadata * _Nullable metadata, NSError * _Nullable error);

extern NSString * _Nonnull const MSIDTrustedAuthorityWorldWide;

@interface MSIDAuthority : NSObject

@property (class, readonly, nonnull) MSIDCache *openIdConfigurationCache;

+ (BOOL)isADFSInstance:(nonnull NSString *)endpoint;
+ (BOOL)isADFSInstanceURL:(nonnull NSURL *)endpointUrl;
+ (BOOL)isConsumerInstanceURL:(nonnull NSURL *)authorityURL;
+ (BOOL)isB2CInstanceURL:(nonnull NSURL *)endpointUrl;

/* AAD v1 endpoint supports only "common" path.
 AAD v2 endpoint supports both common and organizations.
 For legacy cache lookups we need to use common authority for compatibility purposes.
 This method returns "common" authority if "organizations" authority was passed
 Otherwise, returns original authority */
+ (NSURL * _Nullable)universalAuthorityURL:(nullable NSURL *)authorityURL;

+ (BOOL)isTenantless:(nonnull NSURL *)authority;
+ (NSURL *_Nullable)cacheUrlForAuthority:(nonnull NSURL *)authority
                                tenantId:(nullable NSString *)tenantId;

+ (void)resolveAuthority:(nonnull NSURL *)authority
       userPrincipalName:(nullable NSString *)upn
                validate:(BOOL)validate
                 context:(nullable id<MSIDRequestContext>)context
         completionBlock:(nonnull MSIDAuthorityInfoBlock)completionBlock;

+ (void)loadOpenIdConfigurationInfo:(nonnull NSURL *)openIdConfigurationEndpoint
                            context:(nullable id<MSIDRequestContext>)context
                    completionBlock:(nonnull MSIDOpenIdConfigurationInfoBlock)completionB_Nullable_Nonnulllock;

+ (NSURL *_Nullable)normalizeAuthority:(nonnull NSURL *)authority
                               context:(nullable id<MSIDRequestContext>)context
                                 error:(NSError * _Nullable __autoreleasing *_Nullable)error;

+ (BOOL)isKnownHost:(nonnull NSURL *)url;

@end
