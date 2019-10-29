//
//  MSIDAuthSessionHandlerFactory.m
//  IdentityCore
//
//  Created by Olga Dalton on 10/28/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDAuthSessionHandlerFactory.h"
#import "MSIDASWebAuthenticationSessionHandler.h"
#if !TARGET_OS_MACCATALYST
#import "MSIDSFAuthenticationSessionHandler.h"
#endif

@implementation MSIDAuthSessionHandlerFactory

+ (id<MSIDAuthSessionHandling>)authSessionWithParentController:(MSIDViewController *)parentController
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
    
    if (@available(iOS 12.0, macOS 10.15, *))
    {
        return [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController];
    }
    
#if !TARGET_OS_MACCATALYST
    
    if (@available(iOS 11.0, *))
    {
        return [MSIDSFAuthenticationSessionHandler new];
    }
    
#endif
#endif
    
    return nil;
}

@end

#endif
