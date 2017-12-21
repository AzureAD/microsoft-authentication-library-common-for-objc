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

#import <Foundation/Foundation.h>
#import "MSIDTokenRequest.h"
#import "MSIDTokenResponse.h"
#import "MSIDRequestContext.h"
#import "MSIDBrokerResponse.h"
#import "MSIDTokenCacheDataSource.h"
#import "MSIDSharedTokenCacheAccessor.h"

@protocol MSIDOauth2TokenCache <NSObject>

NS_ASSUME_NONNULL_BEGIN

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                         authority:(NSURL *)authority
                      cacheFormats:(NSArray<id<MSIDSharedTokenCacheAccessor>> *)cacheFormats;

- (BOOL)saveTokensWithRequest:(MSIDTokenRequest *)request
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error;

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error;

- (MSIDToken *)getRTForAccount:(MSIDAccount *)account
                      clientId:(NSString *)clientId
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error;

- (MSIDToken *)getFRTforAccount:(MSIDAccount *)account
                       familyId:(NSString *)familyId
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error;

/*!
 Returns all refresh tokens for a given client.
 */
- (NSArray<MSIDToken *> *)getAllRTsForClientId:(NSString *)clientId
                                       context:(id<MSIDRequestContext>)context
                                         error:(NSError **)error;

- (BOOL)removeRTForAccount:(MSIDAccount *)account
                     token:(MSIDToken *)token
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error;

- (BOOL)wipeAccount:(MSIDAccount *)account
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error;

NS_ASSUME_NONNULL_END

@end
