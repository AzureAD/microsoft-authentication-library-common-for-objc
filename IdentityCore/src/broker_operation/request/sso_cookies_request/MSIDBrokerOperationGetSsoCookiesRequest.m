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


#import "MSIDBrokerOperationGetSsoCookiesRequest.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDConstants.h"
#import "NSString+MSIDExtensions.h"

@implementation MSIDBrokerOperationGetSsoCookiesRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_GET_SSO_COOKIES;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        _ssoUrl = [json msidStringObjectForKey:MSID_BROKER_SSO_URL];
        if ([NSString msidIsStringNilOrBlank:self.ssoUrl])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"sso_url is missing in get Sso Cookies operation call.", nil, nil, nil, nil, nil, YES);
            }
            
            return nil;
        }
        
        _correlationId = json[MSID_BROKER_CORRELATION_ID_KEY];
        if(!_correlationId)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"correlation_id is missing in get Sso Cookies operation call.", nil, nil, nil, nil, nil, YES);
            }
            return nil;
        }
        
        if (!json[MSID_BROKER_ACCOUNT_IDENTIFIER])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"account_identifier is not provided from calling app, this is not an error case");
        }
        else
        {
            _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json[MSID_BROKER_ACCOUNT_IDENTIFIER] error:error];
            if ([NSString msidIsStringNilOrBlank:self.accountIdentifier.homeAccountId])
            {
                if (error)
                {
                    *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Account is provided, but homeAccountId is missing from account identifier.", nil, nil, nil, nil, nil, YES);
                }
                
                return  nil;
            }
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;

    // Map to Sso Url
    if ([NSString msidIsStringNilOrBlank:self.ssoUrl]) return nil;
    json[MSID_BROKER_SSO_URL] = self.ssoUrl;
    
    // Map to correlationId
    if (!self.correlationId) return nil;
    json[MSID_BROKER_CORRELATION_ID_KEY] = self.correlationId;
    
    // Map to account identifier, it is nullable.
    // homeAccountId is needed to query Sso Cookies.
    NSDictionary *accountIdentifierJson = [self.accountIdentifier jsonDictionary];
    if (accountIdentifierJson)
    {
        if ([NSString msidIsStringNilOrBlank:self.accountIdentifier.homeAccountId]) return nil;
        json[MSID_BROKER_ACCOUNT_IDENTIFIER] = accountIdentifierJson;
    }

    return json;
}

@end
