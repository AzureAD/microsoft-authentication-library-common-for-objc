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

@class MSIDToken;
@class MSIDTokenCacheKey;
@class MSIDUser;
@class MSIDAdfsToken;

@protocol MSIDTokenCacheDataSource;

@interface MSIDTokenCache : NSObject

- (id)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource;
@property (readonly) id<MSIDTokenCacheDataSource> dataSource;


/*!
 Returns an AT or RT Token Cache Item for given parameters. The RT in this item will only be good
 for the given resource. If no RT is returned in the item then a MRRT or FRT should be used (if
 available).
 */
- (MSIDToken *)getAdalATRTforUser:(MSIDUser *)user
                        authority:(NSURL *)authority
                         resource:(NSString *)resource
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error;

/*!
 Returns a Family Refresh Token for the given authority, user and family ID, if available. A FRT can
 be used for many resources within a given family of client IDs.
 */
- (MSIDToken *)getFRTforUser:(MSIDUser *)user
                   authority:(NSURL *)authority
                    familyId:(NSString *)familyId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error;

/*!
 ADFS is not capable of giving us an idtoken when we authenticate users, so we don't know who got logged
 in or who to cache the tokens for, and instead put the token in a special entry.
 */
- (MSIDAdfsToken *)getAdfsUserTokenForAuthority:(NSURL *)authority
                                       resource:(NSString *)resource
                                       clientId:(NSString *)clientId
                                        context:(id<MSIDRequestContext>)context
                                          error:(NSError **)error;

/*!
 Returns an AT for MSAL for given parameters
 */
- (MSIDToken *)getMsalATwithAuthority:(NSURL *)authority
                             clientId:(NSString *)clientId
                               scopes:(NSOrderedSet<NSString *> *)scopes
                                 user:(MSIDUser *)user
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error;

/*!
 Returns a Multi-Resource Refresh Token (MRRT) Cache Item for the given parameters. A MRRT can
 potentially be used for many resources for that given user, client ID and authority.
 */
- (MSIDToken *)getRTforUser:(MSIDUser *)user
                  authority:(NSURL *)authority
                   clientId:(NSString *)clientId
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error;

/*!
 Returns all refresh tokens for a given client.
 */
- (NSArray<MSIDToken *> *)getAllRTsForClientId:(NSString *)clientId
                                       context:(id<MSIDRequestContext>)context
                                         error:(NSError **)error;

/*!
 Following set of methods store tokens in appropriate form.
 */

- (BOOL)saveAdalAT:(MSIDToken *)adalAT
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
          resource:(NSString *)resource
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error;

- (BOOL)saveMsalAT:(MSIDToken *)msalAT
         authority:(NSURL *)authority
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
            scopes:(NSOrderedSet<NSString *> *)scopes
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error;

- (BOOL)saveFRT:(MSIDToken *)rt
           user:(MSIDUser *)user
       familyId:(NSString *)familyId
      authority:(NSURL *)authority
        context:(id<MSIDRequestContext>)context
          error:(NSError **)error;

- (BOOL)saveRT:(MSIDToken *)rt
          user:(MSIDUser *)user
     authority:(NSURL *)authority
      clientId:(NSString *)clientId
       context:(id<MSIDRequestContext>)context
         error:(NSError **)error;

- (BOOL)saveAdfsToken:(MSIDAdfsToken *)adfsToken
            authority:(NSURL *)authority
             resource:(NSString *)resource
             clientId:(NSString *)clientId
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error;

@end

