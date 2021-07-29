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

#if MSID_ENABLE_SSO_EXTENSION
#import <AuthenticationServices/ASAuthorizationOpenIDRequest.h>
#import "MSIDBrokerOperationGetPrtHeaderWithUIRequest.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDAADAuthority.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDOpenIdProviderMetadata.h"

@interface MSIDBrokerOperationGetPrtHeaderWithUIRequest()

@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) NSURL *requestUrl;
@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;
@property (nonatomic) MSIDAADAuthority *authority;


@end

@implementation MSIDBrokerOperationGetPrtHeaderWithUIRequest

+ (void)load
{
    if (@available(iOS 13.0, macOS 10.15, *))
    {
        [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
    }
}

+ (instancetype)prtHeaderRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                    requestUrl:(NSURL *)requestUrl
                             accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                                 correlationId:(NSUUID *)correlationId
                                         error:(NSError **)error
{
    MSIDBrokerOperationGetPrtHeaderWithUIRequest *request = [MSIDBrokerOperationGetPrtHeaderWithUIRequest new];
    request.accountIdentifier = accountIdentifier;
    if (!request.accountIdentifier && parameters.loginHint)
    {
        request.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:parameters.loginHint homeAccountId:nil];
    }
    request.requestUrl = requestUrl;
    request.correlationId = correlationId;
    
    
    // Resign authority with requestUrl
    MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:requestUrl rawTenant:nil context:nil error:error];
    
    if (!authority)
    {
        return nil;
    }
    
    __auto_type tokenEndpoint = [MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider oauth2TokenEndpointWithUrl:authority.url];
    
    authority.metadata = [MSIDOpenIdProviderMetadata new];
    authority.metadata.tokenEndpoint = tokenEndpoint;
    request.authority = authority;
    return request;
}


+ (NSString *)operation
{
    if (@available(iOS 13.0, macOS 10.15, *))
    {
        return ASAuthorizationOperationLogin;
    }
    
    return @"login";
}

@end
#endif
