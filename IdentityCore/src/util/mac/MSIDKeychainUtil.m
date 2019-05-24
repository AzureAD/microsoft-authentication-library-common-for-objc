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
#import "MSIDKeychainUtil+Internal.h"

@implementation MSIDKeychainUtil

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.teamId = [self getTeamId];
    }
    
    return self;
}

+ (MSIDKeychainUtil *)sharedInstance
{
    static MSIDKeychainUtil *singleton = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        singleton = [[self alloc] init];
    });
    
    return singleton;
}

- (NSString *)getTeamId
{
    NSString *keychainTeamId = nil;
    SecCodeRef selfCode = NULL;
    SecCodeCopySelf(kSecCSDefaultFlags, &selfCode);
    
    if (selfCode)
    {
        CFDictionaryRef cfDic = NULL;
        SecCodeCopySigningInformation(selfCode, kSecCSSigningInformation, &cfDic);
        
        if (!cfDic)
        {
            MSID_LOG_ERROR(nil, @"Failed to retrieve code signing information");
            CFRelease(selfCode);
            return nil;
        }
        
        NSDictionary* signingDic = CFBridgingRelease(cfDic);
        keychainTeamId = [signingDic objectForKey:(__bridge NSString*)kSecCodeInfoTeamIdentifier];
        
        if (!keychainTeamId)
        {
            MSID_LOG_ERROR(nil, @"Failed to retrieve team identifier");
            CFRelease(selfCode);
            return nil;
        }
        
        MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, nil, @"Using \"%@\" Team ID.", _PII_NULLIFY(keychainTeamId));
        MSID_LOG_PII(MSIDLogLevelInfo, nil, nil, @"Using \"%@\" Team ID.", keychainTeamId);
        CFRelease(selfCode);
    }
    
    return keychainTeamId;
}

- (NSString *)accessGroup:(NSString *)group
{
    if (!group)
    {
        return nil;
    }
    
    if (!self.teamId)
    {
        return nil;
    }
    
    return [[NSString alloc] initWithFormat:@"%@.%@", self.teamId, group];
}

@end
