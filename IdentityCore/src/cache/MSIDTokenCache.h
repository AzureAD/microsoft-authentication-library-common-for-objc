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

@protocol MSIDTokenCacheDataSource;

@interface MSIDTokenCache : NSObject

- (id)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource;
- (id<MSIDTokenCacheDataSource>)dataSource;

// Access token needs authority, clientId, scopes, userIdentifier, environment
// Refresh token needs environment, clientId, userIdentifier
//- (BOOL)saveMsalAT:(MSIDToken *)token
//         authority:(NSString *)authority
//          clientId:(NSString *)clientId
//            scopes:(NSSet *)scopes
//       environment:(NSString *)environment
//           context:(id<MSIDRequestContext>)context
//             error:(NSError **)error;
//
//- (BOOL)saveMsalRT:(MSIDToken *)token
//          clientId:(NSString *)clientId
//       environment:(NSString *)environment
//           context:(id<MSIDRequestContext>)context
//             error:(NSError **)error;

// Resource: nil for mrrt
//
//- (BOOL)saveAdalToken:(MSIDToken *)token
//            authority:(NSString *)authority
//             resource:(NSString *)resource // nil for mrrt
//             clientId:(NSString *)clientId
//        userIdentifer:(NSString *)userIdentifier
//              context:(id<MSIDRequestContext>)context
//                error:(NSError **)error;

/*!
 Returns a AT/RT Token Cache Item for the given parameters. The RT in this item will only be good
 for the given resource. If no RT is returned in the item then a MRRT or FRT should be used (if
 available).
 */
- (MSIDToken *)getAdalATRTforUser:(MSIDUser *)user
                        authority:(NSString *)authority
                         resource:(NSString *)resource
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error;

- (MSIDToken *)getFRTforUser:(MSIDUser *)user
                   authority:(NSString *)authority
                    familyId:(NSString *)familyId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error;

- (MSIDToken *)getAdfsUserTokenForAuthority:(NSString *)authority
                                   resource:(NSString *)resource
                                   clientId:(NSString *)clientId
                                    context:(id<MSIDRequestContext>)context
                                      error:(NSError **)error;

- (BOOL)getMsalATwithAuthority:(NSURL *)authority
                      clientId:(NSString *)clientId
                        scopes:(NSOrderedSet<NSString *> *)scopes
                          user:(MSIDUser *)user
                   environment:(NSString *)environment
                   accessToken:(MSIDToken **)outAccessToken
                authorityFound:(NSString **)outAuthorityFound
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error;

- (NSArray<MSIDToken *> *)getRTsForUser:(MSIDUser *)user
                            environment:(NSString *)environment
                               clientId:(NSString *)clientId
                                context:(id<MSIDRequestContext>)context
                                  error:(NSError **)error;

- (BOOL)saveAdalAT:(MSIDToken *)adalAT
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
          resource:(NSString *)resource
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error;

- (BOOL)saveMsalAT:(MSIDToken *)msalAT
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
       environment:(NSString *)environment
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error;

- (BOOL)saveRT:(MSIDToken *)rt
          user:(MSIDUser *)user
   environment:(NSString *)environment
      clientId:(NSString *)clientId
       context:(id<MSIDRequestContext>)context
         error:(NSError **)error;



@end

