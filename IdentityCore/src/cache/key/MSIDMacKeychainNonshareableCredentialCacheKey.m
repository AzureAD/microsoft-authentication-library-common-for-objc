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

#import "MSIDMacKeychainNonshareableCredentialCacheKey.h"

@implementation MSIDMacKeychainNonshareableCredentialCacheKey

- (instancetype)initForRefreshTokenWithHomeAccountId:(NSString *)homeAccountId
                                         environment:(NSString *)environment
                                            clientId:(NSString *)clientId
{
    self = [super init];
    
    if (self)
    {
        _homeAccountId = homeAccountId;
        _environment = environment;
        _clientId = clientId;
        _type = [NSNumber numberWithInt:2002];
    }
    
    return self;
}

- (instancetype)initForAccessTokenWithHomeAccountId:(NSString *)homeAccountId
                                        environment:(NSString *)environment
                                              realm:(NSString *)realm
                                           clientId:(NSString *)clientId
                                             target:(NSString *)target
{
    self = [super init];
    
    if (self)
    {
        _homeAccountId = homeAccountId;
        _environment = environment;
        _realm = realm;
        _clientId = clientId;
        _type = [NSNumber numberWithInt:2001];
        _target = target;
    }
    
    return self;
}

- (instancetype)initForIdTokenWithHomeAccountId:(NSString *)homeAccountId
                                    environment:(NSString *)environment
                                          realm:(NSString *)realm
                                       clientId:(NSString *)clientId
{
    self = [super init];
    
    if (self)
    {
        _homeAccountId = homeAccountId;
        _environment = environment;
        _realm = realm;
        _clientId = clientId;
        _type = [NSNumber numberWithInt:2003];
    }
    
    return self;
}

- (NSString *)accountId
{
    NSString * normalizedHomeAccountId = self.homeAccountId.msidTrimmedString.lowercaseString;
    NSString * normalizedEnvironment = self.environment.msidTrimmedString.lowercaseString;
    return [NSString stringWithFormat:@"%@-%@", normalizedHomeAccountId, normalizedEnvironment];
}

- (NSString *)credentialId
{
    NSString * normalizedClientId = self.clientId.msidTrimmedString.lowercaseString;
    NSString * normalizedRealm = self.realm.msidTrimmedString.lowercaseString;
    return [NSString stringWithFormat:@"%@-%@-%@", self.type, normalizedClientId, normalizedRealm];
}

- (NSString *)account
{
    NSString* accessGroup = @"valentins_wonderful_access_group"; // TODO
    NSString* appBundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSString* accountId = self.accountId;

    return [NSString stringWithFormat:@"%@-%@-%@", accessGroup, appBundleId, accountId];
}

- (NSString *)service
{
    if(self.target.length > 0)
    {
        return [NSString stringWithFormat:@"%@-%@", [self credentialId], self.target];
    }
    else
    {
        return [self credentialId];
    }
}

- (NSData *)generic
{
    return [[self credentialId] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)appKey
{
    return @"app_key"; //TODO
}

@end
