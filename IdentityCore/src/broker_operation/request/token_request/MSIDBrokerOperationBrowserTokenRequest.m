//
//  MSIDBrokerOperationBrowserTokenRequest.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/2/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationBrowserTokenRequest.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"
#import "NSDictionary+MSIDJsonSerializable.h"
#import "MSIDConstants.h"
#import "MSIDConfiguration.h"

@implementation MSIDBrokerOperationBrowserTokenRequest

+ (void)load
{
    if (@available(iOS 13.0, *))
    {
        [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
    }
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_GET_PRT;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _configuration = [[MSIDConfiguration alloc] initWithJSONDictionary:json error:error];
        if (!_configuration) return nil;
        if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_KEY required:YES error:error]) return nil;
        if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_BROWSER_REQUEST_KEY required:YES error:error]) return nil;
        self.brokerKey = json[MSID_BROKER_KEY];
        self.requestURL = json[MSID_BROKER_BROWSER_REQUEST_KEY];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    
    NSDictionary *configurationJson = [self.configuration jsonDictionary];
    if (!configurationJson)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, self.correlationId, @"Failed to create json for %@ class, configuration is nil.", self.class);
        return nil;
    }
    
    [json addEntriesFromDictionary:configurationJson];
    if (!self.brokerKey)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, self.correlationId, @"Failed to create json for %@ class, brokerKey is nil.", self.class);
        return nil;
    }
    
    json[MSID_BROKER_KEY] = self.brokerKey;
    json[MSID_BROKER_BROWSER_REQUEST_KEY] = self.requestURL;
    return json;
}

@end
