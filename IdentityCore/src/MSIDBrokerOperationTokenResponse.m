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

#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDTokenResult+MSIDJsonSerializable.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDConfiguration+MSIDJsonSerializable.h"
#import "MSIDAccessToken.h"
#import "NSOrderedSet+MSIDExtensions.h"

@implementation MSIDBrokerOperationTokenResponse

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSDictionary.class
                          ofField:@"response_data"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            return nil;
        }
        
        NSDictionary *responseJson = json[@"response_data"];
        MSIDTokenResponse *tokenResponse = [[MSIDTokenResponse alloc] initWithJSONDictionary:responseJson error:error];
        if (!tokenResponse) return nil;

        _configuration = [[MSIDConfiguration alloc] initWithJSONDictionary:responseJson error:error];
        if (!_configuration) return nil;
        
//        __auto_type responseValidator = [MSIDDefaultTokenResponseValidator new];
//        __auto_type oauthFactory = [MSIDAADV2Oauth2Factory new];
        
        __auto_type responseValidator = [MSIDTokenResponseValidator new];
        __auto_type oauthFactory = [MSIDOauth2Factory new];
        
        // TODO: fix.
        NSUUID *correlationID = [NSUUID new];
        
        _result = [responseValidator validateTokenResponse:tokenResponse
                                              oauthFactory:oauthFactory
                                             configuration:_configuration
                                            requestAccount:nil
                                             correlationID:correlationID
                                                     error:error];
        if (!_result) return nil;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSString *accessToken = self.result.accessToken.accessToken;
    NSString *scope = [self.result.accessToken.scopes msidToString];
    NSString *refreshToken = self.result.refreshToken.refreshToken;
    NSInteger expiresIn = [self.result.accessToken.expiresOn timeIntervalSinceNow];
    NSString *tokenType = MSID_OAUTH2_BEARER; // TODO:?
    NSString *idToken = self.result.rawIdToken;
    
    NSError *localError;
    MSIDTokenResponse *tokenResponse = [[MSIDTokenResponse alloc] initWithAccessToken:accessToken
                                                                         refreshToken:refreshToken
                                                                            expiresIn:expiresIn
                                                                            tokenType:tokenType
                                                                                scope:scope
                                                                                state:nil
                                                                              idToken:idToken
                                                                 additionalServerInfo:nil
                                                                                error:nil
                                                                     errorDescription:nil
                                                                            initError:&localError];
    
    if (localError)
    {
        // TODO: log error.
        return nil;
    }
    
    NSMutableDictionary *responseJson = [[tokenResponse jsonDictionary] mutableDeepCopy];
    
    NSDictionary *configurationJson = [self.configuration jsonDictionary];
    if (!configurationJson) return nil;
    
    [responseJson addEntriesFromDictionary:configurationJson];
    
    json[@"response_data"] = responseJson;
    
    return json;
}

@end
