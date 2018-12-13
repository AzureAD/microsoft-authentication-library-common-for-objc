//
//  ADBAutomationActionManager.m
//  ADBAutomationApp
//
//  Created by Olga Dalton on 12/12/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDAutomationActionManager.h"

@interface MSIDAutomationActionManager()

@property (nonatomic, strong) NSDictionary<NSString *,id<MSIDAutomationTestAction>> *testActions;

@end

@implementation MSIDAutomationActionManager

+ (MSIDAutomationActionManager *)sharedInstance
{
    static MSIDAutomationActionManager *singleton = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        singleton = [[MSIDAutomationActionManager alloc] init];
    });

    return singleton;
}

- (void)configureActions:(NSDictionary<NSString *,id<MSIDAutomationTestAction>> *)actions
{
    self.testActions = actions;
}

- (id<MSIDAutomationTestAction>)actionForIdentifier:(NSString *)actionIdentifier
{
    return self.testActions[actionIdentifier];
}

- (NSArray<NSString *> *)actionIdentifiers
{
    return [self.testActions allKeys];
}

@end
