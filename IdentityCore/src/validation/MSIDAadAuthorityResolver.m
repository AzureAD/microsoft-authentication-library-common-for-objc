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

#import "MSIDAadAuthorityResolver.h"
#import "MSIDAADGetAuthorityMetadataRequest.h"
#import "MSIDAuthority.h"
#import "MSIDAadAuthorityCache.h"

// Trusted authorities
static NSString *const MSIDTrustedAuthority             = @"login.windows.net";
static NSString *const MSIDTrustedAuthorityUS           = @"login.microsoftonline.us";
static NSString *const MSIDTrustedAuthorityChina        = @"login.chinacloudapi.cn";
static NSString *const MSIDTrustedAuthorityGermany      = @"login.microsoftonline.de";
static NSString *const MSIDTrustedAuthorityWorldWide    = @"login.microsoftonline.com";
static NSString *const MSIDTrustedAuthorityUSGovernment = @"login-us.microsoftonline.com";
static NSString *const MSIDTrustedAuthorityCloudGovApi  = @"login.cloudgovapi.us";

static NSSet<NSString *> *s_trustedHostList;

@implementation MSIDAadAuthorityResolver

+ (void)initialize
{
    s_trustedHostList = [NSSet setWithObjects:MSIDTrustedAuthority,
                         MSIDTrustedAuthorityUS,
                         MSIDTrustedAuthorityChina,
                         MSIDTrustedAuthorityGermany,
                         MSIDTrustedAuthorityWorldWide,
                         MSIDTrustedAuthorityUSGovernment,
                         MSIDTrustedAuthorityCloudGovApi, nil];
                         // login.microsoftonline.us ???
}

- (void)discoverAuthority:(NSURL *)authority
        userPrincipalName:(NSString *)upn
                 validate:(BOOL)validate
                  context:(id<MSIDRequestContext>)context
          completionBlock:(MSIDAuthorityInfoBlock)completionBlock
{
    __auto_type aadCache = [MSIDAadAuthorityCache sharedInstance];
    
    NSURL *trustedHost = [[NSURL alloc] initWithString:MSIDTrustedAuthorityWorldWide];
    if ([MSIDAuthority isKnownHost:authority])
    {
        trustedHost = authority;
    }
    
    __auto_type endpoint = [trustedHost URLByAppendingPathComponent:MSID_OAUTH2_INSTANCE_DISCOVERY_SUFFIX];
    
    __auto_type *request = [[MSIDAADGetAuthorityMetadataRequest alloc] initWithEndpoint:endpoint authority:authority];
    request.context = context;
    [request sendWithBlock:^(MSIDAADAuthorityMetadataResponse *response, NSError *error)
     {
         if (error)
         {
             if ([error.userInfo[MSIDOAuthErrorKey] isEqualToString:@"invalid_instance"])
             {
                 [aadCache addInvalidRecord:authority oauthError:error context:context];
             }
             
             __auto_type endpoint = validate ? nil : [self defaultOpenIdConfigurationEndpointForAuthority:authority];
             NSURL *auth = validate ? nil : authority;
             error = validate ? error : nil;
             
             completionBlock(auth, endpoint, NO, error);
             return;
         }
         
         if (![aadCache processMetadata:response.metadata
                              authority:authority
                                context:context
                                  error:&error])
         {
             completionBlock(nil, nil, NO, error);
             return;
         }
         
         completionBlock(authority, response.openIdConfigurationEndpoint, YES, nil);
     }];
}

- (NSURL *)defaultOpenIdConfigurationEndpointForAuthority:(NSURL *)authority
{
    if (!authority) return nil;
    
    return [authority URLByAppendingPathComponent:@"v2.0/.well-known/openid-configuration"];
}

@end
