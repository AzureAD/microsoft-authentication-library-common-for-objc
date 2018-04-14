//
//  MSIDWebViewController.h
//  IdentityCore iOS
//
//  Created by Jason Kim on 4/10/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MSIDWebOAuth2Response

@protocol MSIDWebUI

typedef void (^MSIDWebUICompletionHandler)(MSIDWebOAuth2Response *response, NSError *error);

- (void)startWebUIWithURL:(NSURL *)url
                   endURL:(NSURL *)endURL
             headerValues:(NSDictionary *)headerValues
                  context:(id<MSIDRequestContext>)context
        completionHandler:(MSIDWebUICompletionHandler)completionHandler;

//Cancel the web authentication session which might be happening right now
//Note that it only works if there's an active web authentication session going on
- (BOOL)cancelCurrentWebAuthSessionWithError:(NSError *)error;

@end
