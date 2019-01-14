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

@class MSIDCredentialCacheItem;
@class MSIDAccountCacheItem;

@interface MSIDStorageManager : NSObject

/**
 * Gets all credentials which match the parameters. May return a partial list of credentials
 * if failed to read all of them, in which case the error result may be set.
 * correlationId: optional
 * homeAccountId: required
 * environment: required
 * realm: optional. Empty string means "match all".
 * clientId: required
 * target: optional. Empty string means "match all".
 * type: required. It's a collection of types. The API should return all types which are present in the set.
 * error: optional
 */
- (nullable NSArray<MSIDCredentialCacheItem *> *)readCredentials:(nullable NSString *)correlationId
                                                   homeAccountId:(nullable NSString *)homeAccountId
                                                     environment:(nullable NSString *)environment
                                                           realm:(nullable NSString *)realm
                                                        clientId:(nullable NSString *)clientId
                                                          target:(nullable NSString *)target
                                                           types:(nullable NSSet<NSNumber *> *)types
                                                           error:(NSError *_Nullable *_Nullable)error;

/**
 * Writes all credentials in the list to the storage.
 * correlationId: optional
 * credentials: the list of credentials to write. They don't have to fall under the same environment, account, or user.
 * error: optional
 */
- (BOOL)writeCredentials:(nullable NSString *)correlationId
             credentials:(nullable NSArray<MSIDCredentialCacheItem *> *)credentials
                   error:(NSError *_Nullable *_Nullable)error;

/** Deletes all matching credentials. Parameters mirror read_credentials. */
- (BOOL)deleteCredentials:(nullable NSString *)correlationId
            homeAccountId:(nullable NSString *)homeAccountId
              environment:(nullable NSString *)environment
                    realm:(nullable NSString *)realm
                 clientId:(nullable NSString *)clientId
                   target:(nullable NSString *)target
                    types:(nullable NSSet<NSNumber *> *)types
                    error:(NSError *_Nullable *_Nullable)error;

/**
 * Reads all accounts present in the cache. May return a partial list of accounts if failed
 * to read all of them, in which case the error result may be set.
 * correlationId: optional
 * error: optional
 */
- (nullable NSArray<MSIDAccountCacheItem *> *)readAllAccounts:(nullable NSString *)correlationId
                                                        error:(NSError *_Nullable *_Nullable)error;

/**
 * Reads an account object, if present. If account is not present in the cache, error is nil
 * with "account" being nil.
 * correlationId: optional
 * homeAccountId: required
 * environment: required
 * realm: required
 * error: optional
 */
- (nullable MSIDAccountCacheItem *)readAccount:(nullable NSString *)correlationId
                                 homeAccountId:(nullable NSString *)homeAccountId
                                   environment:(nullable NSString *)environment
                                         realm:(nullable NSString *)realm
                                         error:(NSError *_Nullable *_Nullable)error;

/**
 * Write an account object into cache. A non-nil error means that the account wasn't written.
 * correlationId: optional
 * account: required
 * error: optional
 */
- (BOOL)writeAccount:(nullable NSString *)correlationId
             account:(nullable MSIDAccountCacheItem *)account
               error:(NSError *_Nullable *_Nullable)error;

/**
 * Deletes an account and all associated credentials.
 * Specifically, it removes all associated access tokens and id tokens.
 * It does not remove any refresh tokens or family refresh tokens, because those are associated with multiple accounts.
 * correlationId: optional
 * homeAccountId: required
 * environment: required
 * realm: required
 * error: optional
 */
- (BOOL)deleteAccount:(nullable NSString *)correlationId
        homeAccountId:(nullable NSString *)homeAccountId
          environment:(nullable NSString *)environment
                realm:(nullable NSString *)realm
                error:(NSError *_Nullable *_Nullable)error;

/**
 * Deletes all information associated with a given homeAccountId and environment.
 * This includes all accounts, access tokens, id tokens, refresh tokens, and family refresh tokens.
 * correlationId: optional
 * homeAccountId: required
 * environment: optional. Empty string means "match all".
 * error: optional
 */
- (BOOL)deleteAccounts:(nullable NSString *)correlationId
         homeAccountId:(nullable NSString *)homeAccountId
           environment:(nullable NSString *)environment
                 error:(NSError *_Nullable *_Nullable)error;

@end
