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

#import "MSIDTestConfiguration.h"
#import "MSIDConfiguration.h"
#import "MSIDTestIdentifiers.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "NSString+MSIDTestUtil.h"

@implementation MSIDTestConfiguration

+ (MSIDConfiguration *)defaultParams
{
    
    
    return [[MSIDConfiguration alloc] initWithAuthority:[DEFAULT_TEST_AUTHORITY aadAuthority]
                                            redirectUri:nil
                                               clientId:DEFAULT_TEST_CLIENT_ID
                                                 target:nil];
}

+ (MSIDConfiguration *)configurationWithB2CAuthority:(NSString *)authorityUrlString
                                            clientId:(NSString *)clientId
                                         redirectUri:(NSString *)redirectUri
                                              target:(NSString *)target
{
    
    return [[MSIDConfiguration alloc] initWithAuthority:[authorityUrlString b2cAuthority]
                                            redirectUri:redirectUri
                                               clientId:clientId
                                                 target:target];
}

+ (MSIDConfiguration *)configurationWithAuthority:(NSString *)authorityUrlString
                                         clientId:(NSString *)clientId
                                      redirectUri:(NSString *)redirectUri
                                           target:(NSString *)target
{
    
    return [[MSIDConfiguration alloc] initWithAuthority:[authorityUrlString aadAuthority]
                                            redirectUri:redirectUri
                                               clientId:clientId
                                                 target:target];
}

+ (MSIDConfiguration *)v1DefaultConfiguration
{
    return [self configurationWithAuthority:DEFAULT_TEST_AUTHORITY
                                   clientId:DEFAULT_TEST_CLIENT_ID
                                redirectUri:nil
                                     target:DEFAULT_TEST_RESOURCE];
}

+ (MSIDConfiguration *)v2DefaultConfiguration
{
    return [self configurationWithAuthority:DEFAULT_TEST_AUTHORITY
                                   clientId:DEFAULT_TEST_CLIENT_ID
                                redirectUri:nil
                                     target:DEFAULT_TEST_SCOPE];
}

+ (MSIDConfiguration *)v2DefaultConfigurationWithScopes:(NSOrderedSet<NSString *> *)scopes
{
    return [self configurationWithAuthority:DEFAULT_TEST_AUTHORITY
                                   clientId:DEFAULT_TEST_CLIENT_ID
                                redirectUri:nil
                                     target:[scopes msidToString]];
}

@end

