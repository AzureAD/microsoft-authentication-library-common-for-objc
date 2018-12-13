//
//  ADBAutomation.h
//  ADBAutomationApp
//
//  Created by Olga Dalton on 12/12/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

typedef void (^MSIDAutoParamBlock)(NSDictionary<NSString *, NSString *> * parameters);
typedef void (^MSIDAutoCompletionBlock)(NSDictionary *result, NSString *logOutput);

#import <WebKit/WebKit.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
@compatibility_alias MSIDAutoViewController UIViewController;
#else
#import <Cocoa/Cocoa.h>
@compatibility_alias MSIDAutoViewController NSViewController;
#endif
