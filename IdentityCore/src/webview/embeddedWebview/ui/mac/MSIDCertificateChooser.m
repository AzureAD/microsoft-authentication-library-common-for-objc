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

#import <SecurityInterface/SFChooseIdentityPanel.h>
#import "MSIDCertificateChooser.h"
#import "MSIDMainThreadUtil.h"
#import <MSIDNotifications.h>

@implementation MSIDCertificateChooserHelper
{
    NSUUID *_correlationId;
    NSWindow *_window;
    SFChooseIdentityPanel *_panel;
    void (^_completionHandler)(SecIdentityRef identity);
}

+ (void)showCertSelectionSheet:(NSArray *)identities
                          host:(NSString *)host
                       webview:(WKWebView *)webview
                 correlationId:(NSUUID *)correlationId
             completionHandler:(void (^)(SecIdentityRef identity))completionHandler
{
    NSString *localizedTemplate = NSLocalizedString(@"Please select a certificate for %1", @"certificate dialog selection prompt \"%1\" will be replaced with the URL host");
    NSString *message = [localizedTemplate stringByReplacingOccurrencesOfString:@"%1" withString:host];
    
    MSIDCertificateChooserHelper *helper = [MSIDCertificateChooserHelper new];
    helper->_correlationId = correlationId;
    helper->_window = webview.window;
    helper->_completionHandler = completionHandler;
    [helper showCertSelectionSheet:identities message:message];
}

- (void)beginSheet:(NSArray *)identities
           message:(NSString *)message
{
    
    _panel = [SFChooseIdentityPanel new];
    [_panel setAlternateButtonTitle:NSLocalizedString(@"Cancel", "Cancel button on cert selection sheet")];
    [_panel beginSheetForWindow:_window
                  modalDelegate:self
                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
                    contextInfo:NULL
                     identities:identities
                        message:message];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webAuthDidFail:) name:MSIDNotifications.webAuthDidFailNotificationName object:nil];
}

- (void)showCertSelectionSheet:(NSArray *)identities
                       message:(NSString *)message
{
    MSID_LOG_WITH_CORR(MSIDLogLevelInfo, _correlationId, @"Displaying Cert Selection Sheet");
    
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        [self beginSheet:identities message:message];
    }];
}

- (void)sheetDidEnd:(__unused NSWindow *)window
         returnCode:(NSInteger)returnCode
        contextInfo:(__unused void *)contextInfo
{
    _window = nil;
    if (returnCode != NSModalResponseOK)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelInfo, _correlationId, @"no certificate selected");
        _completionHandler(NULL);
        return;
    }
    
    SecIdentityRef identity = _panel.identity;
    _completionHandler(identity);
    _completionHandler = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MSIDNotifications.webAuthDidFailNotificationName object:nil];
}

- (void)webAuthDidFail:(__unused NSNotification *)aNotification
{
    if (!_panel || !_window)
    {
        return;
    }
    
    // If web auth fails while the sheet is up that usually means the connection timed out, tear
    // down the cert selection sheet.
    
    MSID_LOG_WITH_CORR(MSIDLogLevelInfo, _correlationId, @"Aborting cert selection due to web auth failure");
    NSArray *sheets = _window.sheets;
    if (sheets.count < 1)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, _correlationId, @"Unable to find sheet to dismiss for client cert auth handler.");
        return;
    }
    // It turns out the SFChooseIdentityPanel is not the real sheet that gets displayed, so telling the window to end it
    // results in nothing happening. If I instead pull out the sheet from the window itself I can tell the window to end
    // that and it works.
    [_window endSheet:sheets[0] returnCode:NSModalResponseCancel];
}

@end
