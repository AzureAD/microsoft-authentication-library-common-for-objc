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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MSIDCredentialType)
{
    MSIDCredentialTypeOther = 0,
    MSIDAccessTokenType = 1,
    MSIDRefreshTokenType = 2,
    MSIDIDTokenType = 3,
    MSIDLegacySingleResourceTokenType = 4,
    MSIDPrimaryRefreshTokenType = 5,
    MSIDLegacyIDTokenType = 6,
    MSIDAccessTokenWithAuthSchemeType = 7,
    MSIDFamilyRefreshTokenType = 8,
    MSIDCredentialTypeLast
};

@interface MSIDCredentialTypeHelpers : NSObject

+ (NSString *)credentialTypeAsString:(MSIDCredentialType)type;
+ (MSIDCredentialType)credentialTypeFromString:(NSString *)type;
+ (MSIDCredentialType)credentialTypeWithRefreshToken:(NSString *)refreshToken accessToken:(NSString *)accessToken;
+ (NSNumber *)credentialTypeNumber:(MSIDCredentialType)credentialType;

@end
