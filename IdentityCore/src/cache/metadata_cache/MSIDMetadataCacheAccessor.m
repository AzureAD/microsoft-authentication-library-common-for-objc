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

#import "MSIDMetadataCacheAccessor.h"
#import "MSIDConfiguration.h"
#import "MSIDRequestParameters.h"
#import "MSIDMetadataCacheAside.h"
#import "MSIDAuthorityMapCacheKey.h"
#import "MSIDAuthorityMap.h"

@implementation MSIDMetadataCacheAccessor
{
    MSIDMetadataCacheAside *_metadataCache;
}

- (instancetype)initWithDataSource:(id<MSIDMetadataCacheDataSource>)dataSource
{
    if (!dataSource) return nil;
    
    self = [super init];
    
    if (self)
    {
        _metadataCache = [[MSIDMetadataCacheAside alloc] initWithDataSource:dataSource];
    }
    
    return self;
}

- (MSIDAuthority *)cacheLookupAuthorityForAuthority:(MSIDAuthority *)requestAuthority
                                  accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                                      configuration:(MSIDConfiguration *)configuration
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error

{
    MSIDAuthorityMapCacheKey *key = [[MSIDAuthorityMapCacheKey alloc] initWithAccountIdentifier:accountIdentifier clientId:configuration.clientId];
    
    MSIDAuthorityMap *authorityMap = (MSIDAuthorityMap *)[_metadataCache metadataItemWithKey:key ofType:MSIDAuthorityMap.class context:context error:error];
    
    if (!authorityMap) return nil;
    
    return [authorityMap cacheLookupAuthorityForAuthority:requestAuthority];
}

- (BOOL)updateAuthorityMapWithRequestParameters:(MSIDRequestParameters *)parameters
                                 cacheAuthority:(MSIDAuthority *)cacheAuthority
                              accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                                        context:(id<MSIDRequestContext>)context
                                          error:(NSError **)error
{
    //No need to update if the request authority is the same as the authority used internally
    if (!cacheAuthority.url || parameters.authority.url == cacheAuthority.url) return YES;
    
    MSIDAuthorityMapCacheKey *key = [[MSIDAuthorityMapCacheKey alloc] initWithAccountIdentifier:accountIdentifier clientId:parameters.clientId];
    
    MSIDAuthorityMap *authorityMap = (MSIDAuthorityMap *)[_metadataCache metadataItemWithKey:key ofType:MSIDAuthorityMap.class context:context error:error];
    
    if (!authorityMap)
    {
        authorityMap = [[MSIDAuthorityMap alloc] initWithAccountIdentifier:accountIdentifier clientId:parameters.clientId];
    }
    
    [authorityMap addMappingWithRequestAuthority:parameters.authority
                               internalAuthority:cacheAuthority];
    
    return [_metadataCache updateMetadataItem:authorityMap withKey:key ofType:MSIDAuthorityMap.class context:context error:error];
}

@end
