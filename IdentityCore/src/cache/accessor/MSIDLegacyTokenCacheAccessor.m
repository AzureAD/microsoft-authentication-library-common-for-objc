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

#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeyedArchiverSerializer.h"

@interface MSIDLegacyTokenCacheAccessor()
{
    NSURL * _authority;
    NSArray<id<MSIDSharedTokenCacheAccessor>> *_cacheFormats;
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDKeyedArchiverSerializer *_serializer;
}

@end

@implementation MSIDLegacyTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                         authority:(NSURL *)authority
                      cacheFormats:(NSArray<id<MSIDSharedTokenCacheAccessor>> *)cacheFormats
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _authority = authority;
        _cacheFormats = cacheFormats;
        _serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    }
    
    return self;
}

#pragma mark - MSIDOauth2TokenCache

- (BOOL)saveTokensWithRequest:(MSIDTokenRequest *)request
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    return NO;
}

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return NO;
}

#pragma mark - MSIDSharedTokenCacheAccessor

- (BOOL)saveRTForUser:(MSIDUser *)user
         refreshToken:(MSIDToken *)refreshToken
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    return NO;
}

- (MSIDToken *)getClientRTForUser:(MSIDUser *)user
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    return nil;
}

- (MSIDToken *)getFRTForUser:(MSIDUser *)user
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    return nil;
}

@end
