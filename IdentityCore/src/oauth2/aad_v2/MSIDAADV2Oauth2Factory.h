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

#import "MSIDAADOauth2Factory.h"
@class MSIDBoundRefreshToken;
@class MSIDRequestParameters;
@class MSIDAADRefreshTokenGrantRequest;

@interface MSIDAADV2Oauth2Factory : MSIDAADOauth2Factory

///
/// Creates and returns a refresh token grant request using the provided request parameters and bound refresh token.
///
/// @param parameters The request parameters containing information such as client ID, scopes, and authority.
/// @param refreshToken The bound refresh token to be used for the grant request.
/// @param context The request context for logging and telemetry purposes.
/// @param error Pointer to an NSError object that will be set if an error occurs during request creation.

/// @return An instance of MSIDAADRefreshTokenGrantRequest if the request is successfully created, or nil if an error occurs.

/// @discussion This method constructs a refresh token grant request for AAD v2 endpoint using a bound refresh token. If the request cannot be created, the error parameter will be set with the appropriate error information.
- (MSIDAADRefreshTokenGrantRequest *)boundRefreshTokenRequestWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                      refreshToken:(MSIDBoundRefreshToken *)refreshToken
                                                                    requestContext:(id<MSIDRequestContext>)context
                                                                             error:(NSError **)error;

@end
