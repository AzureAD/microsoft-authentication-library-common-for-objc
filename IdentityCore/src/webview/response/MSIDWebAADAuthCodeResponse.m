//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDWebAADAuthCodeResponse.h"
#import "MSIDAuthorizationCodeResult.h"
#import "MSIDInteractiveTokenRequestParameters.h"

@implementation MSIDWebAADAuthCodeResponse

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        _cloudHostName = self.parameters[MSID_AUTH_CLOUD_INSTANCE_HOST_NAME];
        _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:self.parameters[MSID_OAUTH2_CLIENT_INFO] error:nil];
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
               requestState:(NSString *)requestState
         ignoreInvalidState:(BOOL)ignoreInvalidState
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    self = [super initWithURL:url requestState:requestState ignoreInvalidState:ignoreInvalidState context:context error:error];
    if (self)
    {
        _cloudHostName = self.parameters[MSID_AUTH_CLOUD_INSTANCE_HOST_NAME];
        _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:self.parameters[MSID_OAUTH2_CLIENT_INFO] error:nil];
    }
    return self;
}

#pragma mark - MSIDWebOAuth2AuthCodeResponse

- (MSIDAuthorizationCodeResult *)createAuthorizationCodeResult
{
    __auto_type result = [super createAuthorizationCodeResult];
    result.accountIdentifier = self.clientInfo.accountIdentifier;
    
    return result;
}

- (void)updateRequestParameters:(MSIDInteractiveTokenRequestParameters *)requestParameters
{
    [super updateRequestParameters:requestParameters];
    
    // handle instance aware flow (cloud host)
    [requestParameters setCloudAuthorityWithCloudHostName:self.cloudHostName];
}

@end
