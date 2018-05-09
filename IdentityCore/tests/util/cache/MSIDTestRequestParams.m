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

#import "MSIDTestRequestParams.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestCacheIdentifiers.h"
#import "NSOrderedSet+MSIDExtensions.h"

@implementation MSIDTestRequestParams

+ (MSIDRequestParameters *)defaultParams
{
    return [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:DEFAULT_TEST_AUTHORITY]
                                                redirectUri:nil
                                                   clientId:DEFAULT_TEST_CLIENT_ID
                                                     target:nil
                                              correlationId:nil];
}

+ (MSIDRequestParameters *)paramsWithAuthority:(NSString *)authority
                                      clientId:(NSString *)clientId
                                   redirectUri:(NSString *)redirectUri
                                        target:(NSString *)target
{
    return [[MSIDRequestParameters alloc] initWithAuthority:[NSURL URLWithString:authority]
                                                redirectUri:redirectUri
                                                   clientId:clientId
                                                     target:target
                                              correlationId:nil];
}

+ (MSIDRequestParameters *)v1DefaultParams
{
    return [self paramsWithAuthority:DEFAULT_TEST_AUTHORITY
                            clientId:DEFAULT_TEST_CLIENT_ID
                         redirectUri:nil
                              target:DEFAULT_TEST_RESOURCE];
}

+ (MSIDRequestParameters *)v2DefaultParams
{
    return [self paramsWithAuthority:DEFAULT_TEST_AUTHORITY
                            clientId:DEFAULT_TEST_CLIENT_ID
                         redirectUri:nil
                              target:DEFAULT_TEST_SCOPE];
}

+ (MSIDRequestParameters *)v2DefaultParamsWithScopes:(NSOrderedSet<NSString *> *)scopes
{
    return [self paramsWithAuthority:DEFAULT_TEST_AUTHORITY
                            clientId:DEFAULT_TEST_CLIENT_ID
                         redirectUri:nil
                              target:[scopes msidToString]];
}

@end
