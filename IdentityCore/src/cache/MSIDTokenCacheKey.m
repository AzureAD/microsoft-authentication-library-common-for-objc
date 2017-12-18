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

#import "MSIDTokenCacheKey.h"
#import "NSString+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"

//A special attribute to write, instead of nil/empty one.
static NSString *const s_nilKey = @"CC3513A0-0E69-4B4D-97FC-DFB6C91EE132";
static NSString *const s_adalLibraryString = @"MSOpenTech.ADAL.1";

static uint32_t const s_msalV1 = 'MSv1';

@implementation MSIDTokenCacheKey

- (id)initWithAccount:(NSString *)account
              service:(NSString *)service
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.account = account;
    self.service = service;
    
    return self;
}

//We should not put nil keys in the keychain. The method substitutes nil with a special GUID:
+ (NSString *)getAttributeName:(NSString *)original
{
    return ([NSString msidIsStringNilOrBlank:original]) ? s_nilKey : [original msidBase64UrlEncode];
}

+ (NSString *)serviceWithAuthority:(NSString *)authority
                          resource:(NSString *)resource
                          clientId:(NSString *)clientId
{
    
    return [NSString stringWithFormat:@"%@|%@|%@|%@",
            s_adalLibraryString,
            authority.msidBase64UrlEncode,
            [self.class getAttributeName:resource.msidBase64UrlEncode],
            clientId.msidBase64UrlEncode];
}

+ (NSString *)accountWithUserIdentifier:(NSString *)userId
                            environment:(NSString *)environment
{
    return userId? [NSString stringWithFormat:@"%u$%@@%@", s_msalV1, userId, environment]: nil;
}

+ (NSString *)serviceWithAuthority:(NSString *)authority
                            scopes:(NSOrderedSet<NSString *> *)scopes
                          clientId:(NSString *)clientId
{
    if (scopes.count == 0)
    {
        return nil;
    }
        
    return [NSString stringWithFormat:@"%@$%@$%@",
            authority? authority.msidBase64UrlEncode : @"",
            clientId? clientId.msidBase64UrlEncode : @"",
            scopes? scopes.msidToString.msidBase64UrlEncode : @""];
}

+ (MSIDTokenCacheKey *)keyForAdfsUserTokenWithAuthority:(NSString *)authority
                                               clientId:(NSString *)clientId
                                               resource:(NSString *)resource
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:@""
                                              service:[self.class serviceWithAuthority:authority
                                                                              resource:resource
                                                                              clientId:clientId]];
}


+ (MSIDTokenCacheKey *)keyWithAuthority:(NSString *)authority
                               clientId:(NSString *)clientId
                               resource:(NSString *)resource
                                    upn:(NSString *)upn
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:upn
                                              service:[self.class serviceWithAuthority:authority
                                                                              resource:resource
                                                                              clientId:clientId]];
}

+ (MSIDTokenCacheKey *)keyForAccessTokenWithAuthority:(NSString *)authority
                                             clientId:(NSString *)clientId
                                               scopes:(NSOrderedSet<NSString *> *)scopes
                                               userId:(NSString *)userId
{
    NSString *service = [self.class serviceWithAuthority:authority scopes:scopes clientId:clientId];
    NSString *account = [self.class accountWithUserIdentifier:userId
                                                  environment:[NSURL URLWithString:authority].msidHostWithPortIfNecessary];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:account service:service];
}

+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUserId:(NSString *)userId
                                           environment:(NSString *)environment
{
    NSString *account = [self.class accountWithUserIdentifier:userId environment:environment];
    return [[MSIDTokenCacheKey alloc] initWithAccount:account service:nil];
}


// rt with uid and utid
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithUserId:(NSString *)userId
                                           clientId:(NSString *)clientId
                                        environment:(NSString *)environment
{
    NSString *service = clientId.msidBase64UrlEncode;
    NSString *account = [self.class accountWithUserIdentifier:userId environment:environment];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:account service:service];
}

+ (MSIDTokenCacheKey *)keyForRefreshTokenWithClientId:(NSString *)clientId
{
    NSString *service = clientId.msidBase64UrlEncode;
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil service:service];
}

+ (MSIDTokenCacheKey *)keyForAllItems
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil service:nil];
}

@end
