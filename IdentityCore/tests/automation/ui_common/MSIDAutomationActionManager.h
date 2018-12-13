//
//  ADBAutomationActionManager.h
//  ADBAutomationApp
//
//  Created by Olga Dalton on 12/12/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDAutomationTestAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAutomationActionManager : NSObject

+ (MSIDAutomationActionManager *)sharedInstance;
- (void)configureActions:(NSDictionary<NSString *,id<MSIDAutomationTestAction>> *)actions;
- (id<MSIDAutomationTestAction>)actionForIdentifier:(NSString *)actionIdentifier;
- (NSArray<NSString *> *)actionIdentifiers;

@end

NS_ASSUME_NONNULL_END
