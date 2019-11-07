//
//  MSIDAuthSessionHandling.h
//  IdentityCore iOS
//
//  Created by Olga Dalton on 10/26/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_IPHONE
@compatibility_alias MSIDViewController UIViewController;
#else
@compatibility_alias MSIDViewController NSViewController;
#endif

typedef void (^MSIDAuthSessionCompletionHandler)(NSURL *callbackURL, NSError *authError);

@protocol MSIDAuthSessionHandling <NSObject>

- (void)startSessionWithWithURL:(NSURL *)URL
              callbackURLScheme:(NSString *)callbackURLScheme
     ephemeralWebBrowserSession:(BOOL)prefersEphemeralWebBrowserSession
              completionHandler:(MSIDAuthSessionCompletionHandler)completionHandler;

- (void)cancel;
                            
@end

NS_ASSUME_NONNULL_END
