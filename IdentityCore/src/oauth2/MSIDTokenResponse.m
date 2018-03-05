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

#import "MSIDTokenResponse.h"

@implementation MSIDTokenResponse

// Default properties for an error response
MSID_JSON_ACCESSOR(MSID_OAUTH2_ERROR, error)
MSID_JSON_ACCESSOR(MSID_OAUTH2_ERROR_DESCRIPTION, errorDescription)

// Default properties for a successful response
MSID_JSON_ACCESSOR(MSID_OAUTH2_EXPIRES_IN, expiresIn)
MSID_JSON_ACCESSOR(MSID_OAUTH2_ACCESS_TOKEN, accessToken)
MSID_JSON_ACCESSOR(MSID_OAUTH2_TOKEN_TYPE, tokenType)
MSID_JSON_ACCESSOR(MSID_OAUTH2_REFRESH_TOKEN, refreshToken)
MSID_JSON_ACCESSOR(MSID_OAUTH2_SCOPE, scope)
MSID_JSON_ACCESSOR(MSID_OAUTH2_STATE, state)
MSID_JSON_ACCESSOR(MSID_OAUTH2_ID_TOKEN, idToken)

- (NSDate *)expiryDate
{
    NSString *expiresIn = self.expiresIn;
    
    if (!expiresIn)
    {
        if (_json[MSID_OAUTH2_EXPIRES_IN])
        {
            MSID_LOG_WARN(nil, @"Unparsable time - The response value for the access token expiration cannot be parsed: %@", _json[MSID_OAUTH2_EXPIRES_IN]);
        }
        
        return nil;
    }
    
    return [NSDate dateWithTimeIntervalSinceNow:[expiresIn integerValue]];
}

- (BOOL)isMultiResource
{
    return YES;
}

- (MSIDIdToken *)idTokenObj
{
    return [[MSIDIdToken alloc] initWithRawIdToken:self.idToken];
}

- (NSError *)getOAuthError:(id<MSIDRequestContext>)context
          fromRefreshToken:(BOOL)fromRefreshToken;
{
    // Method should be implemented in subclasses
    return nil;
}

- (BOOL)verifyExtendedProperties:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    // Method should be implemented in subclasses
    return YES;
}

@end
