//
//  MSIDAutomationMockFlightActionParameters.m
//  IdentityCore
//
//  Created by Ameya Patil on 12/19/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//
#import "MSIDAutomationMockFlightActionParameters.h"
#import "MSIDAutomationTestRequest.h"

@implementation MSIDAutomationMockFlightActionParameters


- (id)initWithFlightKey:(NSString *)flightKey
        mockedBoolValue:(BOOL)boolValue
           queryKeyType:(NSString *)queryKeyType
          queryKeyValue:(NSString *)queryKeyValue
{
    if (self = [super init])
    {
        if (!flightKey)
            return nil;
        
        _flightKey = flightKey;
        _mockedBoolValue = boolValue;
        _queryKeyType = queryKeyType;
        _queryKeyValue = queryKeyValue;
    }
    return self;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(__unused NSError * __autoreleasing *)error
{
    self = [super init];
    if (self)
    {
        _flightKey = json[@"flightKey"];
        _mockedBoolValue = [json[@"mockedBoolValue"] boolValue];
        _queryKeyType = json[@"queryKeyType"];
        _queryKeyValue = json[@"queryKeyValue"];
    }
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *mutableJson = [NSMutableDictionary new];
    mutableJson[@"flightKey"] = _flightKey;
    mutableJson[@"mockedBoolValue"] = @(_mockedBoolValue);
    mutableJson[@"queryKeyType"] = _queryKeyType;
    mutableJson[@"queryKeyValue"] = _queryKeyValue;
    return [mutableJson copy];
}

@end
