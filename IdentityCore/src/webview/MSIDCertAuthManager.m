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


#import "MSIDCertAuthManager.h"
#import "MSIDSystemWebviewController.h"
#import "MSIDMainThreadUtil.h"
#import "NSDictionary+MSIDQueryItems.h"

@interface MSIDCertAuthManager()

@property (nonatomic) MSIDSystemWebviewController *systemWebViewController;
@property (nonatomic) NSString *redirectPrefix;
@property (nonatomic) NSString *redirectScheme;;
@property (nonatomic) BOOL isCertAuthInProgress;

@end

@implementation MSIDCertAuthManager

+ (instancetype)sharedInstance
{
    static MSIDCertAuthManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self.class alloc] init];
    });
    
    return sharedInstance;
}

#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV

- (void)setRedirectUriPrefix:(NSString *)prefix
                   forScheme:(NSString *)scheme
{
    self.redirectPrefix = prefix;
    self.redirectScheme = scheme;
}

- (void)resetState
{
    self.isCertAuthInProgress = NO;
}

- (BOOL)completeWithCallbackURL:(NSURL *)url
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Complete cert auth challenge with end URL: %@", [url msidPIINullifiedURL]);
    
    if (self.isCertAuthInProgress)
    {
        return [self.systemWebViewController handleURLResponse:url];
    }
    
    return NO;
}

- (void)startWithURL:(NSURL *)startURL
    parentController:(MSIDViewController *)parentViewController
             context:(id<MSIDRequestContext>)context
     completionBlock:(MSIDWebUICompletionHandler)completionBlock
{
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        self.isCertAuthInProgress = YES;
        
        NSURLComponents *requestURLComponents = [NSURLComponents componentsWithURL:startURL resolvingAgainstBaseURL:NO];
        NSArray<NSURLQueryItem *> *queryItems = [requestURLComponents queryItems];
        
        NSMutableDictionary *newQueryItems = [NSMutableDictionary new];
        newQueryItems[MSID_BROKER_IS_PERFORMING_CBA] = @"true";
        
        for (NSURLQueryItem *item in queryItems)
        {
            if ([item.name isEqualToString:MSID_OAUTH2_REDIRECT_URI] && !self.useAuthSession && self.redirectScheme != nil)
            {
                NSString *redirectSchemePrefix = [NSString stringWithFormat:@"%@://", self.redirectScheme];
                if (![item.value.lowercaseString hasPrefix:redirectSchemePrefix.lowercaseString])
                {
                    newQueryItems[MSID_OAUTH2_REDIRECT_URI] = [self.redirectPrefix stringByAppendingString:item.value.msidURLEncode];
                    continue;
                }
            }
            
            newQueryItems[item.name] = item.value;
        }
        
        requestURLComponents.percentEncodedQuery = [newQueryItems msidURLEncode];
        NSString *redirectURI = newQueryItems[MSID_OAUTH2_REDIRECT_URI];
        
        self.systemWebViewController = [[MSIDSystemWebviewController alloc] initWithStartURL:requestURLComponents.URL
                                                                                 redirectURI:redirectURI
                                                                            parentController:parentViewController
                                                                    useAuthenticationSession:self.useAuthSession
                                                                   allowSafariViewController:YES
                                                                  ephemeralWebBrowserSession:YES
                                                                                     context:context];
        
        self.systemWebViewController.appActivities = self.activities;
        
        [self.systemWebViewController startWithCompletionHandler:completionBlock];
    }];
}

#endif
@end
