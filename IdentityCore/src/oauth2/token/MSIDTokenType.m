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

#import "MSIDTokenType.h"

@implementation MSIDTokenTypeHelpers

+ (NSString *)tokenTypeAsString:(MSIDTokenType)type
{
    switch (type)
    {
        case MSIDTokenTypeAccessToken:
            return MSID_ACCESS_TOKEN_CACHE_TYPE;
            
        case MSIDTokenTypeRefreshToken:
            return MSID_REFRESH_TOKEN_CACHE_TYPE;
            
        case MSIDTokenTypeLegacyADFSToken:
            return MSID_ADFS_TOKEN_CACHE_TYPE;
            
        case MSIDTokenTypeIDToken:
            return MSID_ID_TOKEN_CACHE_TYPE;
            
        default:
            return MSID_GENERAL_TOKEN_CACHE_TYPE;
    }
}

static NSDictionary *tokenTypes = nil;

// TODO: dispatch once
+ (MSIDTokenType)tokenTypeFromString:(NSString *)type
{
    if (!tokenTypes)
    {
        tokenTypes = @{MSID_ACCESS_TOKEN_CACHE_TYPE: @(MSIDTokenTypeAccessToken),
                       MSID_REFRESH_TOKEN_CACHE_TYPE: @(MSIDTokenTypeRefreshToken),
                       MSID_ADFS_TOKEN_CACHE_TYPE: @(MSIDTokenTypeLegacyADFSToken),
                       MSID_ID_TOKEN_CACHE_TYPE: @(MSIDTokenTypeIDToken),
                       MSID_GENERAL_TOKEN_CACHE_TYPE: @(MSIDTokenTypeOther)
                       };
    }
    
    NSNumber *tokenType = tokenTypes[type];
    return tokenType ? [tokenType integerValue] : MSIDTokenTypeOther;
}

@end
