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

#import "MSIDBoundRefreshToken.h"
#import "MSIDBoundRefreshTokenRedemptionParameters.h"

NS_ASSUME_NONNULL_BEGIN
@interface MSIDBoundRefreshToken (Redemption)
/*!
    @brief For specified tenant ID, get a signed JWT request to redeem this bound refresh token. Tenant ID is used to query registration and match device ID from it to this bound refresh token.
    @param tenantId The tenant ID that will be used to query the device registration.
    @param jweCrypto Optional dictionary to receive JWE crypto information. It will be also part of the resulting JWT's payload.
    @param error Pointer to an NSError object that will be set if an error occurs.
    @return A JWT string for token redemption, or nil if an error occurs.
*/
- (NSString *) getTokenRedemptionJwtForTenantId: (nullable NSString *)tenantId
                      tokenRedemptionParameters: (MSIDBoundRefreshTokenRedemptionParameters *)requestParameters
                                      jweCrypto: (NSDictionary * _Nullable)jweCrypto
                                        context:(id<MSIDRequestContext> _Nullable)context
                                          error: (NSError * __autoreleasing *)error;
@end
NS_ASSUME_NONNULL_END
