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
#import "MSIDConstants.h"

@interface MSIDASWebAuthenticationSessionHandler () <ASWebAuthenticationPresentationContextProviding>

@property (weak, nonatomic) MSIDViewController *parentController;
@property (nonatomic) NSURL *startURL;
@property (nonatomic) NSString *callbackURLScheme;
@property (nonatomic) ASWebAuthenticationSession *webAuthSession;
@property (nonatomic) BOOL useEmpheralSession;
@property (nonatomic) BOOL sessionDismissed;

@end

@implementation MSIDASWebAuthenticationSessionHandler

#pragma mark - MSIDAuthSessionHandling

- (instancetype)initWithParentController:(MSIDViewController *)parentController
                                startURL:(NSURL *)startURL
                          callbackScheme:(NSString *)callbackURLScheme
                      useEmpheralSession:(BOOL)useEmpheralSession
{
    self = [super init];
    
    if (self)
    {
        _parentController = parentController;
        _startURL = startURL;
        _callbackURLScheme = callbackURLScheme;
        _useEmpheralSession = useEmpheralSession;
    }
    
    return self;
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    void (^authCompletion)(NSURL *, NSError *) = ^void(NSURL *callbackURL, NSError *authError)
    {
        if (self.sessionDismissed)
        {
            self.webAuthSession = nil;
            return;
        }
        
        self.sessionDismissed = YES;
        
        if (authError.code == ASWebAuthenticationSessionErrorCodeCanceledLogin)
        {
            NSError *cancelledError = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, nil, nil, YES);
            
            self.webAuthSession = nil;
            if (completionHandler) completionHandler(nil, cancelledError);
            return;
        }
        
        self.webAuthSession = nil;
        if (completionHandler) completionHandler(callbackURL, authError);
    };
    
    self.webAuthSession = [[ASWebAuthenticationSession alloc] initWithURL:self.startURL
                                                        callbackURLScheme:self.callbackURLScheme
                                                        completionHandler:authCompletion];
    
    self.webAuthSession.presentationContextProvider = self;
    self.webAuthSession.prefersEphemeralWebBrowserSession = self.useEmpheralSession;
    
    if (![self.webAuthSession start] && !self.sessionDismissed)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Failed to start an interactive session", nil, nil, nil, nil, nil, YES);
        if (completionHandler) completionHandler(nil, error);
    }
}

- (void)cancelProgrammatically
{
    [self.webAuthSession cancel];
}

- (void)userCancel
{
    [self cancelProgrammatically];
}

- (void)dismiss
{
    self.sessionDismissed = YES;
    [self cancelProgrammatically];
}

#pragma mark - ASWebAuthenticationPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(__unused ASWebAuthenticationSession *)session
{
    return [self presentationAnchor];
}

- (ASPresentationAnchor)presentationAnchor
{
    if (![NSThread isMainThread])
    {
        __block ASPresentationAnchor anchor;
        dispatch_sync(dispatch_get_main_queue(), ^{
            anchor = [self presentationAnchor];
        });
        
        return anchor;
    }
    
    __typeof__(self.parentController) parentController = self.parentController;
    
#if TARGET_OS_OSX
    return parentController ? parentController.view.window : [NSApplication sharedApplication].keyWindow;
#else
    return parentController.view.window;
#endif
}

@end

#endif
