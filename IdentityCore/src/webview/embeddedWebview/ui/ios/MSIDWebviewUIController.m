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

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDWebviewUIController.h"
#import "UIApplication+MSIDExtensions.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDBackgroundTaskManager.h"
#import "MSIDMainThreadUtil.h"

#if defined TARGET_OS_VISION && TARGET_OS_VISION
static inline CGRect ActiveScreenBounds(void)
{
    // this code is also compiled for extensions where UIApplication.sharedApplication is not available
    UIApplication *sharedApp = nil;
    if ([UIApplication respondsToSelector:NSSelectorFromString(@"sharedApplication")])
    {
        sharedApp = [UIApplication performSelector:NSSelectorFromString(@"sharedApplication")];
    }

    UIWindowScene *activeScene = nil;
    for (UIWindowScene *scene in sharedApp.connectedScenes)
    {
        if (scene.activationState == UISceneActivationStateForegroundActive)
        {
            activeScene = scene;
            break;
        }
    }

    if ((activeScene == nil) && (sharedApp.connectedScenes.count > 0))
    {
        activeScene = (UIWindowScene *)sharedApp.connectedScenes.anyObject;
    }

    if (activeScene != nil)
    {
        return activeScene.coordinateSpace.bounds;
    }

    return CGRectZero;
}

static inline CGRect ActiveSceneBoundsForView(UIView *view)
{
    UIWindowScene *activeScene = view.window.windowScene;
    if(activeScene != nil)
    {
        return activeScene.coordinateSpace.bounds;
    }

    return ActiveScreenBounds();
}
#endif

static WKWebViewConfiguration *s_webConfig;

@interface MSIDWebviewUIController ()
{
    UIActivityIndicatorView *_loadingIndicator;
}

@property (nonatomic) BOOL presentInParentController;

@end

@implementation MSIDWebviewUIController

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // initialize method can never be called simultaneously with any other MSAIMSIDWebviewUIController method
        // hence there is no need to synchronize access to s_webConfig here
        s_webConfig = [MSIDWebviewUIController defaultWKWebviewConfiguration];
    });
}

+ (WKWebViewConfiguration *)defaultWKWebviewConfiguration
{
    WKWebViewConfiguration *webConfig = [WKWebViewConfiguration new];
    webConfig.applicationNameForUserAgent = kMSIDPKeyAuthKeyWordForUserAgent;
    webConfig.defaultWebpagePreferences.preferredContentMode = WKContentModeMobile;
    
    // QR+PIN auth inside a WKWebView requires these settings
    // This allows the camera to be automatically triggered when redirected to the QR scanning page, instead
    // of a user action like a button press
    webConfig.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    // This allows the camera to show inline, otherwise it defaults to showing up fullscreen
    webConfig.allowsInlineMediaPlayback = YES;

    return webConfig;
}

+ (void)setSharedWKWebviewConfiguration:(WKWebViewConfiguration *)configuration
{
    @synchronized(self) {
        s_webConfig = configuration;
    }
}

- (id)initWithContext:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _context = context;
    }
    
    return self;
}

- (id)initWithContext:(id<MSIDRequestContext>)context
       platformParams:(MSIDWebViewPlatformParams *)platformParams
{
    self = [super init];
    if (self)
    {
        _context = context;
        _platformParams = platformParams;
    }

    return self;
}

- (void)dealloc
{
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
}

- (BOOL)loadView:(NSError *__autoreleasing*)error
{
    /* Start background transition tracking,
     so we can start a background task, when app transitions to background */
    [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
    
    if (_webView)
    {
        self.presentInParentController = NO;
        return YES;
    }
    
    // Get UI container to hold the webview
    // Need parent controller to proceed
    if (![self obtainParentController])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorNoMainViewController, @"The Application does not have a current ViewController", nil, nil, nil, _context.correlationId, nil, YES);
        }
        return NO;
    }
    UIView *rootView = [self view];
#if defined TARGET_OS_VISION && TARGET_OS_VISION
    CGRect screenBounds = ActiveSceneBoundsForView(rootView);
#else
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
#endif
    [rootView setFrame:screenBounds];
    [rootView setAutoresizesSubviews:YES];
    [rootView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    
    // Prepare the WKWebView
    WKWebView *webView = [[WKWebView alloc] initWithFrame:rootView.frame configuration:s_webConfig];
    [webView setAccessibilityIdentifier:@"MSID_SIGN_IN_WEBVIEW"];
    
    // Customize the UI
    [webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self setupCancelButton];
    _loadingIndicator = [self prepareLoadingIndicator:rootView];
    self.view = rootView;
    
    // Append webview and loading indicator
    _webView = webView;
    [rootView addSubview:_webView];
    [rootView addSubview:_loadingIndicator];
    
    // WKWebView was created by MSAL, present it in parent controller.
    // Otherwise we rely on developer to show the web view.
    self.presentInParentController = YES;
    
    return YES;
}

- (void)presentView
{
    if (!self.presentInParentController) return;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self];
    [navController setModalPresentationStyle:_presentationType];
    
    [navController setModalInPresentation:YES];
    
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        [self.parentController presentViewController:navController animated:YES completion:nil];
    }];
}

- (void)dismissWebview:(void (^)(void))completion
{
    __typeof__(self.parentController) parentController = self.parentController;
    
    //if webview is created by us, dismiss and then complete and return;
    //otherwise just complete and return.
    if (parentController && self.presentInParentController)
    {
        [parentController dismissViewControllerAnimated:YES completion:completion];
    }
    else
    {
        completion();
    }
    
    self.parentController = nil;
}

- (void)showLoadingIndicator
{
    [_loadingIndicator setHidden:NO];
    [_loadingIndicator startAnimating];
}

- (void)dismissLoadingIndicator
{
    [_loadingIndicator setHidden:YES];
    [_loadingIndicator stopAnimating];
}

- (BOOL)obtainParentController
{
    __typeof__(self.parentController) parentController = self.parentController;
    
    if (parentController) return YES;
    
    return NO;
}

- (void)setupCancelButton
{
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(userCancel)];
    self.navigationItem.leftBarButtonItem = cancelButton;
}

- (UIActivityIndicatorView *)prepareLoadingIndicator:(UIView *)rootView
{
    UIActivityIndicatorView *loadingIndicator;
    loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];

    [loadingIndicator setColor:[UIColor blackColor]];
    [loadingIndicator setCenter:rootView.center];
    return loadingIndicator;
}

// This is reserved for subclass to handle programatic cancellation.
- (void)cancel
{
    // Overridden in subclass with cancel logic
}

- (void)userCancel
{
    // Overridden in subclass with userCancel logic
}

@end

#endif
