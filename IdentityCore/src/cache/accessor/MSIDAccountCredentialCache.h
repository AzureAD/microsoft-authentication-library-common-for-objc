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
#import "MSIDTokenType.h"
#import "MSIDAccountType.h"

@class MSIDTokenCacheItem;
@class MSIDAccountCacheItem;
@class MSIDDefaultTokenCacheKey;
@protocol MSIDTokenCacheDataSource;

@interface MSIDAccountCredentialCache : NSObject

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource;

// Reading credentials
/*
 Gets all credentials which match the parameters
 @param uniqueUserId required
 @param environment required
 @param realm optional. Nil string means "match all".
 @param client_id required
 @param target optional. Empty string means "match all".
 @param type: required
*/
- (nullable NSArray<MSIDTokenCacheItem *> *)getCredentialsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                                                               environment:(nonnull NSString *)environment
                                                                     realm:(nullable NSString *)realm
                                                                  clientId:(nonnull NSString *)clientId
                                                                    target:(nullable NSString *)target
                                                                      type:(MSIDTokenType)type
                                                                   context:(nullable id<MSIDRequestContext>)context
                                                                     error:(NSError * _Nullable * _Nullable)error;


/*
 Gets a credential for a particular key
*/
- (nullable MSIDTokenCacheItem *)getCredential:(nonnull MSIDDefaultTokenCacheKey *)key
                                       context:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable * _Nullable)error;

/*
 Gets all credentials which matching parameters
*/
- (nullable NSArray<MSIDTokenCacheItem *> *)getCredentials:(nonnull MSIDDefaultTokenCacheKey *)query
                                                   context:(nullable id<MSIDRequestContext>)context
                                                     error:(NSError * _Nullable * _Nullable)error;

/*
 Gets all credentials which a matching type
*/
- (nullable NSArray<MSIDTokenCacheItem *> *)getAllCredentialsWithType:(MSIDTokenType)type
                                                              context:(nullable id<MSIDRequestContext>)context
                                                                error:(NSError * _Nullable * _Nullable)error;


/*
 Reads all accounts with matching parameters
 @param uniqueUserId required
 @param environment required
 @param realm optional. Nil string means "match all".
*/
- (nullable NSArray<MSIDAccountCacheItem *> *)getAccountsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                                                              environment:(nonnull NSString *)environment
                                                                    realm:(nullable NSString *)realm
                                                                  context:(nullable id<MSIDRequestContext>)context
                                                                    error:(NSError * _Nullable * _Nullable)error;

/*
 Gets an account for a particular key
*/
- (nullable MSIDAccountCacheItem *)getAccount:(nonnull MSIDDefaultTokenCacheKey *)key
                                      context:(nullable id<MSIDRequestContext>)context
                                        error:(NSError * _Nullable * _Nullable)error;

/*
 Gets all accounts which matching parameters
 */
- (nullable NSArray<MSIDAccountCacheItem *> *)getAccounts:(nonnull MSIDDefaultTokenCacheKey *)query
                                                  context:(nullable id<MSIDRequestContext>)context
                                                    error:(NSError * _Nullable * _Nullable)error;

/*
 Gets all accounts which a matching type
 */
- (nullable NSArray<MSIDAccountCacheItem *> *)getAllAccountsWithType:(MSIDAccountType)type
                                                             context:(nullable id<MSIDRequestContext>)context
                                                               error:(NSError * _Nullable * _Nullable)error;

/*
 Saves a credential
*/
- (BOOL)saveCredential:(nonnull MSIDTokenCacheItem *)credential
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable * _Nullable)error;

/*
 Saves an account
*/
- (BOOL)saveAccount:(nonnull MSIDAccountCacheItem *)account
            context:(nullable id<MSIDRequestContext>)context
              error:(NSError * _Nullable * _Nullable)error;

/*
 Remove all credentials which match the parameters
 @param uniqueUserId required
 @param environment required
 @param realm optional. Nil string means "match all".
 @param client_id required
 @param target optional. Empty string means "match all".
 @param type: required
 */
- (BOOL)removeCredentialsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                              environment:(nonnull NSString *)environment
                                    realm:(nullable NSString *)realm
                                 clientId:(nonnull NSString *)clientId
                                   target:(nullable NSString *)target
                                     type:(MSIDTokenType)type
                                  context:(nullable id<MSIDRequestContext>)context
                                    error:(NSError * _Nullable * _Nullable)error;

/*
 Removes a credential
*/
- (BOOL)removeCredential:(nonnull MSIDTokenCacheItem *)credential
                 context:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error;

/*
 Removes credentials matching the query
 */
- (BOOL)removeCredentials:(nonnull MSIDDefaultTokenCacheKey *)query
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError * _Nullable * _Nullable)error;

/*
 Removes multiple accounts matching parameters
*/
- (BOOL)removeAccountsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                           environment:(nonnull NSString *)environment
                                 realm:(nullable NSString *)realm
                               context:(nullable id<MSIDRequestContext>)context
                                 error:(NSError * _Nullable * _Nullable)error;

/*
 Removes an account
*/
- (BOOL)removeAccount:(nonnull MSIDAccountCacheItem *)account
              context:(nullable id<MSIDRequestContext>)context
                error:(NSError * _Nullable * _Nullable)error;

/*
 Removes multiple accounts
*/
- (BOOL)removeAccounts:(nonnull MSIDDefaultTokenCacheKey *)query
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable * _Nullable)error;

/*
 Clears the whole cache, should only be used for testing!
 */
- (BOOL)clearWithContext:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error;

/*
 Removes all credentials in the array
 */
- (BOOL)removeAllCredentials:(nonnull NSArray<MSIDTokenCacheItem *> *)credentials
                     context:(nullable id<MSIDRequestContext>)context
                       error:(NSError * _Nullable * _Nullable)error;

@end
