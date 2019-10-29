//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDASWebAuthenticationSessionHandler.h"
#import <AuthenticationServices/AuthenticationServices.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
@interface MSIDASWebAuthenticationSessionHandler () <ASWebAuthenticationPresentationContextProviding>
#else
@interface MSIDASWebAuthenticationSessionHandler ()
#endif
@property (weak, nonatomic) MSIDViewController *parentController;
@property (nonatomic) ASWebAuthenticationSession *webAuthSession;

@end

@implementation MSIDASWebAuthenticationSessionHandler

#pragma mark - MSIDAuthSessionHandling

- (instancetype)initWithParentController:(MSIDViewController *)parentController
{
    self = [super init];
    
    if (self)
    {
        _parentController = parentController;
    }
    
    return self;
}
                                      
- (void)startSessionWithWithURL:(NSURL *)URL
              callbackURLScheme:(NSString *)callbackURLScheme
     ephemeralWebBrowserSession:(BOOL)prefersEphemeralWebBrowserSession
              completionHandler:(void (^)(NSURL *callbackURL, NSError *authError))completionHandler
{
    void (^authCompletion)(NSURL *, NSError *) = ^void(NSURL *callbackURL, NSError *authError)
    {
        if (authError.code == ASWebAuthenticationSessionErrorCodeCanceledLogin)
        {
            NSError *cancelledError = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, nil, nil, YES);
            
            if (completionHandler) completionHandler(nil, cancelledError);
            return;
        }
        
        completionHandler(callbackURL, authError);
    };
    
    self.webAuthSession = [[ASWebAuthenticationSession alloc] initWithURL:URL
                                                        callbackURLScheme:callbackURLScheme
                                                        completionHandler:authCompletion];
    
    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
        if (@available(iOS 13.0, macOS 10.15, *))
        {
            self.webAuthSession.presentationContextProvider = self;
            self.webAuthSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession;
        }
    #endif
    
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

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500

#pragma mark - ASWebAuthenticationPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session API_AVAILABLE(ios(13.0), macCatalyst(13.0), macos(10.15))
{
    return [self presentationAnchor];
}

- (ASPresentationAnchor)presentationAnchor API_AVAILABLE(ios(13.0), macCatalyst(13.0), macos(10.15))
{
    if (![NSThread isMainThread])
    {
        __block ASPresentationAnchor anchor;
        dispatch_sync(dispatch_get_main_queue(), ^{
            anchor = [self presentationAnchor];
        });
        
        return anchor;
    }
    
    return self.parentController.view.window;
}

#endif

@end

#endif
