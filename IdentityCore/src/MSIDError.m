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

NSString *MSIDErrorDescriptionKey = @"MSIDErrorDescriptionKey";
NSString *MSIDOAuthErrorKey = @"MSIDOAuthErrorKey";
NSString *MSIDOAuthSubErrorKey = @"MSIDOAuthSubErrorKey";
NSString *MSIDCorrelationIdKey = @"MSIDCorrelationIdKey";
NSString *MSIDHTTPHeadersKey = @"MSIDHTTPHeadersKey";
NSString *MSIDHTTPResponseCodeKey = @"MSIDHTTPResponseCodeKey";

NSString *MSIDErrorDomain = @"MSIDErrorDomain";
NSString *MSIDOAuthErrorDomain = @"MSIDOAuthErrorDomain";
NSString *MSIDKeychainErrorDomain = @"MSIDKeychainErrorDomain";

NSError *MSIDCreateError(NSString *domain, NSInteger code, NSString *errorDescription, NSString *oauthError, NSString *subError, NSError *underlyingError, NSUUID *correlationId, NSDictionary *additionalUserInfo)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    userInfo[MSIDErrorDescriptionKey] = errorDescription;
    userInfo[MSIDOAuthErrorKey] = oauthError;
    userInfo[MSIDOAuthSubErrorKey] = subError;
    userInfo[NSUnderlyingErrorKey]  = underlyingError;
    userInfo[MSIDCorrelationIdKey] = correlationId;
    if (additionalUserInfo)
    {
        [userInfo addEntriesFromDictionary:additionalUserInfo];
    }
    
    return [NSError errorWithDomain:domain code:code userInfo:userInfo];
}


MSIDErrorCode MSIDErrorCodeForOAuthError(NSString *oauthError, MSIDErrorCode defaultCode)
{
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_request"] == NSOrderedSame)
    {
        return MSIDErrorInvalidRequest;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_client"] == NSOrderedSame)
    {
        return MSIDErrorInvalidClient;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_scope"] == NSOrderedSame)
    {
        return MSIDErrorInvalidScope;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_grant"] == NSOrderedSame)
    {
        return MSIDErrorInvalidGrant;
    }
    
    return defaultCode;
}
