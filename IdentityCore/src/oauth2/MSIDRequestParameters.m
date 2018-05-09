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

#import "MSIDRequestParameters.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDPkce.h"

@implementation MSIDRequestParameters

- (instancetype)copyWithZone:(NSZone*)zone
{
    MSIDRequestParameters *parameters = [[MSIDRequestParameters allocWithZone:zone] init];
    parameters.authority = [_authority copyWithZone:zone];
    parameters.redirectUri = [_redirectUri copyWithZone:zone];
    parameters.target = [_target copyWithZone:zone];
    parameters.clientId = [_clientId copyWithZone:zone];
    parameters.correlationId = [_correlationId copyWithZone:zone];
    
    parameters.loginHint = [_loginHint copyWithZone:zone];
    parameters.extraQueryParameters = [_extraQueryParameters copyWithZone:zone];
    parameters.promptBehavior = [_promptBehavior copyWithZone:zone];
    parameters.claims = [_claims copyWithZone:zone];

    parameters.correlationId = [_correlationId copyWithZone:zone];
    
    parameters->_pkce = [_pkce copyWithZone:zone];
    parameters.sliceParameters = [_sliceParameters copyWithZone:zone];
    parameters.clientId = [_clientId copyWithZone:zone];
    parameters.requestState = [_requestState copyWithZone:zone];
    
    parameters.explicitStartURL = [_explicitStartURL copyWithZone:zone];
    
    return parameters;
}

- (instancetype)initWithAuthority:(NSURL *)authority
                      redirectUri:(NSString *)redirectUri
                         clientId:(NSString *)clientId
                           target:(NSString *)target
                    correlationId:(NSUUID *)correlationId
{
    self = [super init];
    
    if (self)
    {
        _authority = authority;
        _redirectUri = redirectUri;
        _clientId = clientId;
        _target = target;
        _correlationId = correlationId;
    }
    
    return self;
}

- (NSString *)resource
{
    return _target;
}

- (NSOrderedSet<NSString *> *)scopes
{
    return [_target scopeSet];
}

@end
