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

#import <AppKit/AppKit.h>
#import "MSIDNTLMUIPrompt.h"
#import "MSIDCredentialCollectionController.h"
#import "MSIDMainThreadUtil.h"

@interface MSIDNTLMUIPrompt ()

@end

@implementation MSIDNTLMUIPrompt

__weak static NSAlert *_presentedPrompt = nil;

+ (void)dismissPrompt
{
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        
        if (_presentedPrompt)
        {
            [_presentedPrompt.window.sheetParent endSheet:_presentedPrompt.window];
            _presentedPrompt = nil;
        }
    }];
}

+ (void)presentPrompt:(void (^)(NSString *username, NSString *password, BOOL cancel))completionHandler
{
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        NSAlert *alert = [NSAlert new];
        
        [alert setMessageText:NSLocalizedString(@"Enter your credentials", nil)];
        NSButton *loginButton = [alert addButtonWithTitle:NSLocalizedString(@"Login", nil)];
        NSButton *cancelButton = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        
        MSIDCredentialCollectionController *view = [MSIDCredentialCollectionController new];
        [view.usernameLabel setStringValue:NSLocalizedString(@"Username", nil)];
        [view.passwordLabel setStringValue:NSLocalizedString(@"Password", nil)];
        [alert setAccessoryView:view.customView];
        
        [[alert window] setInitialFirstResponder:view.usernameField];
        
        [alert beginSheetModalForWindow:[NSApp keyWindow] completionHandler:^(NSModalResponse returnCode)
         {
             // The first button being added is "Login" button
             if (returnCode == NSAlertFirstButtonReturn)
             {
                 NSString *username = [view.usernameField stringValue];
                 NSString *password = [view.passwordField stringValue];
                 
                 completionHandler(username, password, NO);
             }
             else
             {
                 completionHandler(nil, nil, YES);
             }
         }];
        
        _presentedPrompt = alert;
        
        [view.usernameField setNextKeyView:view.passwordField];
        [view.passwordField setNextKeyView:cancelButton];
        [cancelButton setNextKeyView:loginButton];
        [loginButton setNextKeyView:view.usernameField];
    }];
}

@end
