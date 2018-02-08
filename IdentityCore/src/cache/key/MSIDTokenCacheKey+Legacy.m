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

#import "MSIDTokenCacheKey+Legacy.h"

//A special attribute to write, instead of nil/empty one.
static NSString *const s_nilKey = @"CC3513A0-0E69-4B4D-97FC-DFB6C91EE132";
static NSString *const s_adalLibraryString = @"MSOpenTech.ADAL.1";

@implementation MSIDTokenCacheKey (Legacy)

#pragma mark - Helpers

//We should not put nil keys in the keychain. The method substitutes nil with a special GUID:
+ (NSString *)getAttributeName:(NSString *)original
{
    return ([NSString msidIsStringNilOrBlank:original]) ? s_nilKey : [original msidBase64UrlEncode];
}

+ (NSString *)serviceWithAuthority:(NSURL *)authority
                          resource:(NSString *)resource
                          clientId:(NSString *)clientId
{
    
    return [NSString stringWithFormat:@"%@|%@|%@|%@",
            s_adalLibraryString,
            authority.absoluteString.msidBase64UrlEncode,
            [self.class getAttributeName:resource.msidBase64UrlEncode],
            clientId.msidBase64UrlEncode];
}

#pragma mark - Legacy keys

+ (MSIDTokenCacheKey *)keyForAdfsUserTokenWithAuthority:(NSURL *)authority
                                               clientId:(NSString *)clientId
                                               resource:(NSString *)resource
{
    NSString *service = [self.class serviceWithAuthority:authority
                                                resource:resource
                                                clientId:clientId];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:@""
                                              service:service
                                              generic:s_adalLibraryString
                                                 type:nil];
}


+ (MSIDTokenCacheKey *)keyWithAuthority:(NSURL *)authority
                               clientId:(NSString *)clientId
                               resource:(NSString *)resource
                                    upn:(NSString *)upn
{
    NSString *service = [self.class serviceWithAuthority:authority
                                                resource:resource
                                                clientId:clientId];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:upn
                                              service:service
                                              generic:s_adalLibraryString
                                                 type:nil];
}

@end
