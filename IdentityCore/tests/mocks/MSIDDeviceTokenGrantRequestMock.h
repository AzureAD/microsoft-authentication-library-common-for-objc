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

// Test subclass that mocks the network layer. The real request builds a signed JWT and
// then calls -sendWithBlock: to hit the token endpoint. In a unit test we can neither sign
// with the (non-signable) mock key material nor perform real networking, so we:
//   1. Override the JWT generation to return a dummy token, allowing the flow to reach the
//      network call.
//   2. Override -sendWithBlock: to synchronously invoke the completion block with an
//      injectable expectedResponse / expectedError, mocking the network response.
#import "MSIDDeviceTokenGrantRequest.h"

@interface MSIDDeviceTokenGrantRequestMock : MSIDDeviceTokenGrantRequest

@property (nonatomic) NSDictionary *expectedResponse;
@property (nonatomic) NSError *expectedError;
@property (nonatomic) BOOL sendWithBlockCalled;

// Private method on MSIDDeviceTokenGrantRequest that we override to bypass JWT signing.
- (NSString *)getTokenRedemptionJwtForResource:(NSString *)resource
                                        scopes:(NSSet *)scopes
                                   redirectUri:(NSString *)redirectUri
                                      audience:(NSString *)audience
                                      clientId:(NSString *)clientId
                            extraPayloadClaims:(NSDictionary *)extraPayloadClaims
                                       context:(id<MSIDRequestContext>)context
                                         error:(NSError * __autoreleasing *)error;

@end
