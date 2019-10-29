//
//  MSIDSFAuthenticationSessionHandler.m
//  IdentityCore iOS
//
//  Created by Olga Dalton on 10/28/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#if !MSID_EXCLUDE_WEBKIT && !TARGET_OS_MACCATALYST

#import "MSIDSFAuthenticationSessionHandler.h"
#import <SafariServices/SafariServices.h>

@interface MSIDSFAuthenticationSessionHandler()

@property (nonatomic) SFAuthenticationSession *webAuthSession;

@end

@implementation MSIDSFAuthenticationSessionHandler

#pragma mark - MSIDAuthSessionHandling
                                      
- (void)startSessionWithWithURL:(NSURL *)URL
              callbackURLScheme:(NSString *)callbackURLScheme
     ephemeralWebBrowserSession:(__unused BOOL)prefersEphemeralWebBrowserSession
              completionHandler:(void (^)(NSURL *callbackURL, NSError *authError))completionHandler
{
    void (^authCompletion)(NSURL *, NSError *) = ^void(NSURL *callbackURL, NSError *authError)
    {
        if (authError.code == SFAuthenticationErrorCanceledLogin)
        {
            NSError *cancelledError = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, nil, nil, YES);
            
            if (completionHandler) completionHandler(nil, cancelledError);
            return;
        }
        
        completionHandler(callbackURL, authError);
    };
    
    self.webAuthSession = [[SFAuthenticationSession alloc] initWithURL:URL
                                                     callbackURLScheme:callbackURLScheme
                                                     completionHandler:authCompletion];
    
    if (![self.webAuthSession start])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Failed to start an interactive session", nil, nil, nil, nil, nil, YES);
        if (completionHandler) completionHandler(nil, error);
    }
    
}

- (void)cancel
{
    [self.webAuthSession cancel];
}


@end

#endif
