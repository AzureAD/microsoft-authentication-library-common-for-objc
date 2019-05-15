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

#import "MSIDKeychainUtil.h"

@implementation MSIDKeychainUtil

+ (NSString *)teamId
{
    static dispatch_once_t once;
    static NSString *keychainTeamId = nil;
    
    dispatch_once(&once, ^{
        SecCodeRef selfCode = NULL;
        SecCodeCopySelf(kSecCSDefaultFlags, &selfCode);
        
        if (selfCode)
        {
            CFDictionaryRef cfDic = NULL;
            SecCodeCopySigningInformation(selfCode, kSecCSSigningInformation, &cfDic);
            NSDictionary* signingDic = CFBridgingRelease(cfDic);
            keychainTeamId = [signingDic objectForKey:(__bridge NSString*)kSecCodeInfoTeamIdentifier];
            
            MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, nil, @"Using \"%@\" Team ID.", _PII_NULLIFY(keychainTeamId));
            MSID_LOG_PII(MSIDLogLevelInfo, nil, nil, @"Using \"%@\" Team ID.", keychainTeamId);
            
            CFRelease(selfCode);
        }
    });
    
    return keychainTeamId;
}

+ (NSString *)accessGroup:(NSString *)group
{
    if (!group)
    {
        return nil;
    }
    
    if (!MSIDKeychainUtil.teamId)
    {
        return nil;
    }
    
    return [[NSString alloc] initWithFormat:@"%@.%@", MSIDKeychainUtil.teamId, group];
}

@end
