//
//  MSIDAutomationMockFlightActionParameters.h
//  IdentityCore
//
//  Created by Ameya Patil on 12/19/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//
#import "MSIDJsonSerializable.h"

NS_ASSUME_NONNULL_BEGIN
@interface MSIDAutomationMockFlightActionParameters : NSObject <MSIDJsonSerializable>

@property (nonatomic, readonly) NSString *flightKey;
@property (nonatomic, readonly) BOOL mockedBoolValue;
@property (nonatomic, readonly) NSString *queryKeyType;
@property (nonatomic, readonly) NSString *queryKeyValue;

-(id) initWithFlightKey:(NSString *)flightKey
        mockedBoolValue:(BOOL)boolValue
           queryKeyType:(NSString *)queryKeyType
          queryKeyValue:(NSString *)queryKeyValue;

- (instancetype _Nullable )init NS_UNAVAILABLE;
+ (instancetype _Nullable )new NS_UNAVAILABLE;

@end
NS_ASSUME_NONNULL_END
