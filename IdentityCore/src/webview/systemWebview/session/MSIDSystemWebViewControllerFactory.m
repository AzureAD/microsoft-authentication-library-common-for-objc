//
//  MSIDAuthSessionHandlerFactory.m
//  IdentityCore
//
//  Created by Olga Dalton on 10/28/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDSystemWebViewControllerFactory.h"
#import "MSIDASWebAuthenticationSessionHandler.h"
#import "MSIDConstants.h"
#if !TARGET_OS_MACCATALYST
#import "MSIDSFAuthenticationSessionHandler.h"
#endif
#import "MSIDSafariViewController.h"

@implementation MSIDSystemWebViewControllerFactory

+ (MSIDWebviewType)defaultWebViewType
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
        
    if (@available(iOS 12.0, macOS 10.15, *))
    {
        return MSIDWebviewTypeAuthenticationSession;
    }
#endif
        
#if !TARGET_OS_MACCATALYST
        
    if (@available(iOS 11.0, *))
    {
        return MSIDWebviewTypeAuthenticationSession;
    }
        
#endif
    
#if TARGET_OS_IPHONE
    return MSIDWebviewTypeSafariViewController;
#endif
    
    return MSIDWebviewTypeWKWebView;
}

+ (id<MSIDWebviewInteracting>)authSessionWithParentController:(MSIDViewController *)parentController
                                                     startURL:(NSURL *)startURL
                                               callbackScheme:(NSString *)callbackURLScheme
                                           useEmpheralSession:(BOOL)useEmpheralSession
                                                      context:(id<MSIDRequestContext>)context
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
    
    if (@available(iOS 12.0, macOS 10.15, *))
    {
        return [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentController
                                                                              startURL:startURL
                                                                        callbackScheme:callbackURLScheme
                                                                    useEmpheralSession:useEmpheralSession];
    }
#endif
    
#if !TARGET_OS_MACCATALYST 
    
    if (@available(iOS 11.0, *))
    {
        return [[MSIDSFAuthenticationSessionHandler alloc] initWithStartURL:startURL callbackScheme:callbackURLScheme];
    }
    
#endif
    
    return nil;
}

#if TARGET_OS_IPHONE

+ (id<MSIDWebviewInteracting>)systemWebviewControllerWithParentController:(MSIDViewController *)parentController
                                                                 startURL:(NSURL *)startURL
                                                           callbackScheme:(NSString *)callbackURLScheme
                                                       useEmpheralSession:(BOOL)useEmpheralSession
                                                         presentationType:(UIModalPresentationStyle)presentationType
                                                                  context:(id<MSIDRequestContext>)context
{
    id<MSIDWebviewInteracting> authSession = [self authSessionWithParentController:parentController
                                                                          startURL:startURL
                                                                    callbackScheme:callbackURLScheme
                                                                useEmpheralSession:useEmpheralSession
                                                                           context:context];
    
    if (authSession)
    {
        return authSession;
    }
    
    return [[MSIDSafariViewController alloc] initWithURL:startURL
                                        parentController:parentController
                                        presentationType:presentationType
                                                 context:context];
}

#endif

@end

#endif
