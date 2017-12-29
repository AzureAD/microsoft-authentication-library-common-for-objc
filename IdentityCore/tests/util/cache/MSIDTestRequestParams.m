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
#import "MSIDAADV1RequestParameters.h"
#import "MSIDAADV2RequestParameters.h"
#import "MSIDTestCacheIdentifiers.h"

@implementation MSIDTestRequestParams

+ (MSIDAADV1RequestParameters *)v1DefaultParams
{
    NSURL *authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    MSIDAADV1RequestParameters *requestParams = [[MSIDAADV1RequestParameters alloc] initWithAuthority:authority
                                                                                          redirectUri:nil
                                                                                             clientId:DEFAULT_TEST_CLIENT_ID
                                                                                             resource:DEFAULT_TEST_RESOURCE];
    
    return requestParams;
}

+ (MSIDAADV2RequestParameters *)v2DefaultParams
{
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil];
    return [self.class v2DefaultParamsWithScopes:scopes];
}

+ (MSIDAADV2RequestParameters *)v2DefaultParamsWithScopes:(NSOrderedSet<NSString *> *)scopes
{
    NSURL *authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    MSIDAADV2RequestParameters *requestParams = [[MSIDAADV2RequestParameters alloc] initWithAuthority:authority
                                                                                          redirectUri:nil
                                                                                             clientId:DEFAULT_TEST_CLIENT_ID
                                                                                               scopes:scopes];
    
    return requestParams;
}
@end
