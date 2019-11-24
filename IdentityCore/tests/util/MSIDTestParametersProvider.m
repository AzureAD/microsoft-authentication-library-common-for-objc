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

#import "MSIDTestParametersProvider.h"
#import "MSIDAADAuthority.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDTestIdentifiers.h"

@implementation MSIDTestParametersProvider

#pragma mark - Helpers

+ (MSIDInteractiveRequestParameters *)testInteractiveParameters
{
    NSUUID *correlationId = [NSUUID new];
    
    MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:DEFAULT_TEST_AUTHORITY] rawTenant:nil context:nil error:nil];
    authority.metadata = [MSIDOpenIdProviderMetadata new];
    
    MSIDInteractiveRequestParameters *parameters = [[MSIDInteractiveRequestParameters alloc] initWithAuthority:authority
                                                                                                   redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                                      clientId:DEFAULT_TEST_CLIENT_ID
                                                                                                        scopes:[NSOrderedSet orderedSetWithObjects:@"scope1", nil]
                                                                                                    oidcScopes:nil
                                                                                          extraScopesToConsent:nil
                                                                                                 correlationId:correlationId
                                                                                                telemetryApiId:nil
                                                                                                 brokerOptions:nil
                                                                                                   requestType:MSIDRequestBrokeredType
                                                                                           intuneAppIdentifier:nil
                                                                                                         error:nil];
    
    return parameters;
}

@end
