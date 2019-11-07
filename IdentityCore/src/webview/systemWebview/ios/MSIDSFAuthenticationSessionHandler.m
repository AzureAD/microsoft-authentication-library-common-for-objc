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
@property (nonatomic) NSURL *startURL;
@property (nonatomic) NSString *callbackURLScheme;

@end

@implementation MSIDSFAuthenticationSessionHandler

- (instancetype)initWithStartURL:(NSURL *)startURL
                  callbackScheme:(NSString *)callbackURLScheme
{
    self = [super init];
    
    if (self)
    {
        _startURL = startURL;
        _callbackURLScheme = callbackURLScheme;
    }
    
    return self;
}

#pragma mark - MSIDAuthSessionHandling
                                      
- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
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
    
    self.webAuthSession = [[SFAuthenticationSession alloc] initWithURL:self.startURL
                                                     callbackURLScheme:self.callbackURLScheme
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
