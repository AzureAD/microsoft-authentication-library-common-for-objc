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

#import "MSIDConfiguration+MSIDJsonSerializable.h"
#import "MSIDAADAuthority.h"

@implementation MSIDConfiguration (MSIDJsonSerializable)

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_CLIENT_ID
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *clientId = json[MSID_OAUTH2_CLIENT_ID];
    
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_REDIRECT_URI
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *redirectUri = json[MSID_OAUTH2_REDIRECT_URI];
    
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_SCOPE
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *scopeString = json[MSID_OAUTH2_SCOPE];
    
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_AUTHORITY
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *authorityString = json[MSID_OAUTH2_AUTHORITY];
    
    if ([NSString msidIsStringNilOrBlank:authorityString])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Authority is missing in the json dictionary.");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Authority is missing in the json dictionary.", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    // TODO: should we support other authorities?
    NSError *localError = nil;
    MSIDAADAuthority *aadAuthority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:authorityString]
                                                                 rawTenant:nil
                                                                   context:nil
                                                                     error:&localError];
    
    if (!aadAuthority)
    {
        if (error)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Non AAD authorities are not supported for json serialization/deserialization - %@", MSID_PII_LOG_MASKABLE(localError));
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Non AAD authorities are not supported in broker", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    self = [self initWithAuthority:aadAuthority
                       redirectUri:redirectUri
                          clientId:clientId
                            target:scopeString];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[MSID_OAUTH2_CLIENT_ID] = self.clientId;
    json[MSID_OAUTH2_REDIRECT_URI] = self.redirectUri;
    json[MSID_OAUTH2_SCOPE] = self.target;
    json[MSID_OAUTH2_AUTHORITY] = self.authority.url.absoluteString;
    
    return json;
}

@end
