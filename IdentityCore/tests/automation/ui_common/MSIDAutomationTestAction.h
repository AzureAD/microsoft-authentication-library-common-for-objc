//
//  ADBAutomationTestAction.h
//  ADBAutomationApp
//
//  Created by Olga Dalton on 12/12/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDAutomation.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MSIDAutomationTestAction <NSObject>

@property (nonatomic, readonly) NSString *actionIdentifier;
@property (nonatomic, readonly) BOOL needsRequestParameters;

- (BOOL)performActionWithParameters:(NSDictionary *)parameters
                containerController:(MSIDAutoViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
