//
//  MSIDAuthSessionHandlerFactory.h
//  IdentityCore
//
//  Created by Olga Dalton on 10/28/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDWebviewInteracting.h"
#import "MSIDConstants.h"

#if !MSID_EXCLUDE_WEBKIT

NS_ASSUME_NONNULL_BEGIN

@interface MSIDSystemWebViewControllerFactory : NSObject

+ (MSIDWebviewType)availableWebViewTypeWithPreferredType:(MSIDWebviewType)preferredType;

+ (id<MSIDWebviewInteracting>)authSessionWithParentController:(MSIDViewController *)parentController
                                                     startURL:(NSURL *)startURL
                                               callbackScheme:(NSString *)callbackURLScheme
                                           useEmpheralSession:(BOOL)useEmpheralSession
                                                      context:(id<MSIDRequestContext>)context;

#if TARGET_OS_IPHONE

+ (id<MSIDWebviewInteracting>)systemWebviewControllerWithParentController:(MSIDViewController *)parentController
                                                                 startURL:(NSURL *)startURL
                                                           callbackScheme:(NSString *)callbackURLScheme
                                                       useEmpheralSession:(BOOL)useEmpheralSession
                                                         presentationType:(UIModalPresentationStyle)presentationType
                                                                  context:(id<MSIDRequestContext>)context;

#endif

@end

NS_ASSUME_NONNULL_END

#endif
