//
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


#import <XCTest/XCTest.h>
#import "MSIDTestSwizzle.h"
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 130000
#import "MSIDASAuthorizationProviderExtensionLoginManagerMock.h"
#import "MSIDExternalSSOContext.h"

@interface MSIDExternalSSOContextTest : XCTestCase

@end

@interface MSIDExternalSSOContext()

- (void)getPlatformSSOIdentity:(SecIdentityRef _Nullable *_Nullable)identityRef API_AVAILABLE(macos(13.0));
- (BOOL)isMigrationFlagSetInLoginManager;

@end

@implementation MSIDExternalSSOContextTest

- (void)testMSIDExternalSSOContext_testGetPlatformSSOIdentity_WhenMigration_ShouldReturnIdentityForUserSigningKey_macOS14
{
    if (@available(macOS 13.0, *))
    {
        MSIDASAuthorizationProviderExtensionLoginManagerMock *loginManagerMock = [MSIDASAuthorizationProviderExtensionLoginManagerMock alloc];
        loginManagerMock.copyIdentityForKeyTypeUserDeviceSigningKeyInvokedCount = 0;
        
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
        if (@available(macOS 14.0, *))
        {
            
            [MSIDTestSwizzle instanceMethod:@selector(isMigrationFlagSetInLoginManager)
                                   class:[MSIDExternalSSOContext class] block:(id)^(void)
             {
                return YES;
            }];
        }
#endif
        MSIDExternalSSOContext *ssoContext = [MSIDExternalSSOContext new];
        [ssoContext setValue:loginManagerMock forKey:@"loginManager"];
        SecIdentityRef identityRef = nil;
        [ssoContext getPlatformSSOIdentity:&identityRef];
        
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
        if (@available(macOS 14.0, *))
        {
            XCTAssertEqual(loginManagerMock.copyIdentityForKeyTypeUserDeviceSigningKeyInvokedCount,1);
        }
        else
        {
            XCTAssertEqual(loginManagerMock.copyIdentityForKeyTypeUserDeviceSigningKeyInvokedCount,1);
        }
#else
        XCTAssertEqual(loginManagerMock.copyIdentityForKeyTypeUserDeviceSigningKeyInvokedCount,1);
#endif
    }
}


- (void)MSIDExternalSSOContext_testGetPlatformSSOIdentity_WhenNotMigration_ShouldReturnIdentityForCurrentSigningKey_macOS14
{
    if (@available(macOS 13.0, *))
    {
        MSIDASAuthorizationProviderExtensionLoginManagerMock *loginManagerMock = [MSIDASAuthorizationProviderExtensionLoginManagerMock alloc];
        loginManagerMock.copyIdentityForKeyTypeUserDeviceSigningKeyInvokedCount = 0;
        loginManagerMock.copyIdentityForKeyTypeCurrentDeviceSigningKeyInvokedCount = 0;
        
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
        if (@available(macOS 14.0, *))
        {
            
            [MSIDTestSwizzle instanceMethod:@selector(isMigrationFlagSetInLoginManager)
                                   class:[MSIDExternalSSOContext class] block:(id)^(void)
             {
                return NO;
            }];
        }
#endif
        MSIDExternalSSOContext *ssoContext = [MSIDExternalSSOContext new];
        [ssoContext setValue:loginManagerMock forKey:@"loginManager"];
        [ssoContext getPlatformSSOIdentity];
        
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
        if (@available(macOS 14.0, *))
        {
            XCTAssertEqual(loginManagerMock.copyIdentityForKeyTypeCurrentDeviceSigningKeyInvokedCount,1);
        }
        else
        {
            XCTAssertEqual(loginManagerMock.copyIdentityForKeyTypeUserDeviceSigningKeyInvokedCount,1);
        }
#else
        XCTAssertEqual(loginManagerMock.copyIdentityForKeyTypeUserDeviceSigningKeyInvokedCount,1);
#endif
    }
}

@end

#endif
