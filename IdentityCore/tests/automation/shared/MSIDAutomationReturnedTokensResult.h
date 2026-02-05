//
//  MSIDAutomationReturnedTokensResult.h
//  IdentityCore
//
//  Created by Ameya Patil on 12/18/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "MSIDAutomationTestResult.h"
#import "MSIDBaseToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAutomationReturnedTokensResult : MSIDAutomationTestResult

@property (nonatomic) NSArray<NSString *> *tokenDescriptions;

- (instancetype)initWithAction:(NSString *)actionId
                        tokens:(NSArray<MSIDBaseToken *> *)tokens
                additionalInfo:(nullable NSDictionary *)additionalInfo;

@end

NS_ASSUME_NONNULL_END
