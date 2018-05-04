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
#import "MSIDAuthorityResolverProtocol.h"

@class MSIDOpenIdProviderMetadata;

typedef void(^MSIDOpenIdConfigurationInfoBlock)(MSIDOpenIdProviderMetadata *metadata, NSError *error);

extern NSString *const MSIDTrustedAuthorityWorldWide;

@interface MSIDAuthority : NSObject

+ (BOOL)isADFSInstance:(NSString *)endpoint;
+ (BOOL)isADFSInstanceURL:(NSURL *)endpointUrl;
+ (BOOL)isConsumerInstanceURL:(NSURL *)authorityURL;

/* AAD v1 endpoint supports only "common" path.
   AAD v2 endpoint supports both common and organizations.
   For legacy cache lookups we need to use common authority for compatibility purposes.
   This method returns "common" authority if "organizations" authority was passed
   Otherwise, returns original authority */
+ (NSURL *)universalAuthorityURL:(NSURL *)authorityURL;

+ (BOOL)isTenantless:(NSURL *)authority;
+ (NSURL *)cacheUrlForAuthority:(NSURL *)authority
                       tenantId:(NSString *)tenantId;

+ (void)discoverAuthority:(NSURL *)authority
        userPrincipalName:(NSString *)upn
                 validate:(BOOL)validate
                  context:(id<MSIDRequestContext>)context
          completionBlock:(MSIDAuthorityInfoBlock)completionBlock;

+ (void)loadOpenIdConfigurationInfo:(NSURL *)openIdConfigurationEndpoint
                            context:(id<MSIDRequestContext>)context
                    completionBlock:(MSIDOpenIdConfigurationInfoBlock)completionBlock;

+ (NSURL *)normalizeAuthority:(NSURL *)authority
                      context:(id<MSIDRequestContext>)context
                        error:(NSError * __autoreleasing *)error;

+ (BOOL)isKnownHost:(NSURL *)url;

@end
