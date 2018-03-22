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

#import "MSIDBrokerResponse.h"
#import "MSIDAADV1TokenResponse.h"

@implementation MSIDBrokerResponse

MSID_FORM_ACCESSOR(MSID_OAUTH2_AUTHORITY, authority);
MSID_FORM_ACCESSOR(MSID_OAUTH2_CLIENT_ID, clientId);
MSID_FORM_ACCESSOR(MSID_OAUTH2_RESOURCE, resource);

MSID_FORM_ACCESSOR(MSID_OAUTH2_ACCESS_TOKEN, accessToken);
MSID_FORM_ACCESSOR(MSID_OAUTH2_REFRESH_TOKEN, refreshToken);
MSID_FORM_ACCESSOR(MSID_OAUTH2_EXPIRES_ON, expiresOn);
MSID_FORM_ACCESSOR(MSID_OAUTH2_ID_TOKEN, idToken);
MSID_FORM_ACCESSOR(MSID_FAMILY_ID, familyId);

MSID_FORM_ACCESSOR(@"x-broker-app-ver", brokerAppVer);
MSID_FORM_ACCESSOR(@"vt", validAuthority);

MSID_FORM_ACCESSOR(MSID_OAUTH2_CORRELATION_ID_RESPONSE, correlationId);
MSID_FORM_ACCESSOR(@"error_code", errorCode);
MSID_FORM_ACCESSOR(MSID_OAUTH2_ERROR_DESCRIPTION, errorDescription);
MSID_FORM_ACCESSOR(MSID_CLIENT_INFO_CACHE_KEY, clientInfo)

- (instancetype)initWithDictionary:(NSDictionary *)form
                             error:(NSError **)error
{
    self = [super initWithDictionary:form error:error];
    
    if (self)
    {
        // Broker only works for AAD for now
        NSMutableDictionary *formDictionary = [form mutableCopy];
        formDictionary[MSID_OAUTH2_TOKEN_TYPE] = @"Bearer";
        
        _tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:formDictionary
                                                                          error:error];
    }
    
    return self;
}

- (NSString *)oauthErrorCode
{
    if (_urlForm[@"protocol_code"])
    {
        return _urlForm[@"protocol_code"];
    }
    
    return _urlForm[@"code"];
}

@end
