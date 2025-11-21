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

#import "MSIDWPJKeyPairWithCert.h"

NS_ASSUME_NONNULL_BEGIN
@interface MSIDBoundRefreshTokenRedemptionParameters : NSObject


// client ID, client_id claim in request payload
@property (nonatomic, copy) NSString *clientId;

// Set of scopes to request in bound refresh token redemption request payload
@property (nonatomic, copy) NSSet <NSString *>*scopes;

// Client nonce GUID to be used in bound refresh token redemption request payload.
@property (nonatomic, copy) NSString *nonce;

// Audience (token endpoint URL) for the bound refresh token redemption request
@property (nonatomic, copy) NSString *audience;

@property (nonatomic, copy, nullable) NSDictionary *extraPayloadClaims;

@property (nonatomic, readonly, nullable) MSIDWPJKeyPairWithCert *workplaceJoinInfo;


- (instancetype)initWithClientId:(NSString *)clientId
               authorityEndpoint:(NSURL *)authorityEndpoint
                          scopes:(NSSet <NSString *>*)scopes
                           nonce:(NSString *)nonce
              extraPayloadClaims:(nullable NSDictionary *)extraPayloadClaims
               workplaceJoinInfo:(nullable MSIDWPJKeyPairWithCert *)workplaceJoinInfo;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

// Returns a modifiable claims payload dictionary for the bound refresh token redemption request.
- (NSMutableDictionary *)jsonDictionary;

@end
NS_ASSUME_NONNULL_END

