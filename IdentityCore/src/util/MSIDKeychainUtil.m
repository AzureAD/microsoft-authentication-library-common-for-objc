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

#pragma mark - Public

+ (NSString *)teamId
{
    static dispatch_once_t once;
    static NSString *keychainTeamId = nil;
    
    dispatch_once(&once, ^{
        NSString *accessGroup = [MSIDKeychainUtil appDefaultAccessGroup];
        NSArray *components = [accessGroup componentsSeparatedByString:@"."];
        NSString *bundleSeedID = [components firstObject];
        keychainTeamId = [bundleSeedID length] ? bundleSeedID : nil;
        
        MSID_LOG_INFO(nil, @"Using \"%@\" Team ID.", _PII_NULLIFY(keychainTeamId));
        MSID_LOG_INFO_PII(nil, @"Using \"%@\" Team ID.", keychainTeamId);
    });
    
    return keychainTeamId;
}

+ (NSString *)appDefaultAccessGroup
{
    static dispatch_once_t once;
    static NSString *appDefaultAccessGroup = nil;
    
    dispatch_once(&once, ^{
        NSDictionary *query = @{ (id)kSecClass : (id)kSecClassGenericPassword,
                                 (id)kSecAttrAccount : @"teamIDHint",
                                 (id)kSecAttrService : @"",
                                 (id)kSecReturnAttributes : @YES };
        CFDictionaryRef result = nil;
        
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        
        if (status == errSecItemNotFound)
        {
            NSMutableDictionary* addQuery = [query mutableCopy];
            [addQuery setObject:(id)kSecAttrAccessibleAlways forKey:(id)kSecAttrAccessible];
            status = SecItemAdd((__bridge CFDictionaryRef)addQuery, (CFTypeRef *)&result);
        }
        
        if (status == errSecSuccess)
        {
            appDefaultAccessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge id)(kSecAttrAccessGroup)];
            MSID_LOG_INFO(nil, @"Defaul app's acces group: \"%@\".", _PII_NULLIFY(appDefaultAccessGroup));
            MSID_LOG_INFO_PII(nil, @"Defaul app's acces group: \"%@\".", appDefaultAccessGroup);
        }
        else
        {
            MSID_LOG_ERROR(nil, @"fetching kSecAttrAccessGroup, status: %d", status);
        }
        
        CFRelease(result);
    });
    
    return appDefaultAccessGroup;
}
@end
