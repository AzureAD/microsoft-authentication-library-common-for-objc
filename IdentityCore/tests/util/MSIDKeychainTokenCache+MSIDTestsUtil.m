//
//  MSIDTestUtil.m
//  IdentityCore
//
//  Created by Sergey Demchenko on 12/4/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"

@implementation MSIDKeychainTokenCache (MSIDTestUtil)

+ (void)reset
{
    [self deleteAllKeysForSecClass:kSecClassGenericPassword];
    [self deleteAllKeysForSecClass:kSecClassInternetPassword];
    [self deleteAllKeysForSecClass:kSecClassCertificate];
    [self deleteAllKeysForSecClass:kSecClassKey];
    [self deleteAllKeysForSecClass:kSecClassIdentity];
}

#pragma mark - Private

+ (void)deleteAllKeysForSecClass:(CFTypeRef)secClass
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    [dict setObject:(__bridge id)secClass forKey:(__bridge id)kSecClass];
    OSStatus result = SecItemDelete((__bridge CFDictionaryRef) dict);
    
    assert(result == noErr || result == errSecItemNotFound);
}

@end
