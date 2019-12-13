// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDBrokerOperationRequest.h"
#import "MSIDConstants.h"
#import "MSIDRequestParameters.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDVersion.h"

@implementation MSIDBrokerOperationRequest

+ (NSString *)operation
{
    NSAssert(NO, @"Abstract method.");
    return @"";
}

+ (BOOL)fillRequest:(MSIDBrokerOperationRequest *)request
keychainAccessGroup:(NSString *)keychainAccessGroup
     clientMetadata:(NSDictionary *)clientMetadata
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    NSString *accessGroup = keychainAccessGroup ?: MSIDKeychainTokenCache.defaultKeychainGroup;
    __auto_type brokerKeyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:accessGroup];
    NSError *brokerError = nil;
    NSString *base64UrlKey = [brokerKeyProvider base64BrokerKeyWithContext:context
                                                                     error:&brokerError];
    
    if (!base64UrlKey)
    {
        if (error) *error = brokerError;
        return NO;
    }
    
    request.brokerKey = base64UrlKey;
    request.clientVersion = [MSIDVersion sdkVersion];
    request.protocolVersion = MSID_BROKER_PROTOCOL_VERSION_4;
    request.clientAppVersion = clientMetadata[MSID_APP_VER_KEY];
    request.clientAppName = clientMetadata[MSID_APP_NAME_KEY];
    request.correlationId = context.correlationId;
    
    return YES;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_KEY required:YES error:error]) return nil;
        _brokerKey = json[MSID_BROKER_KEY];
        
        if (![json msidAssertTypeIsOneOf:@[NSString.class, NSNumber.class] ofKey:MSID_BROKER_PROTOCOL_VERSION_KEY required:YES error:error]) return nil;
        _protocolVersion = [json[MSID_BROKER_PROTOCOL_VERSION_KEY] integerValue];
        
        _clientVersion = [json msidStringObjectForKey:MSID_BROKER_CLIENT_VERSION_KEY];
        _clientAppVersion = [json msidStringObjectForKey:MSID_BROKER_CLIENT_APP_VERSION_KEY];
        _clientAppName = [json msidStringObjectForKey:MSID_BROKER_CLIENT_APP_NAME_KEY];
        
        NSString *uuidString = [json msidStringObjectForKey:MSID_BROKER_CORRELATION_ID_KEY];
        _correlationId = [[NSUUID alloc] initWithUUIDString:uuidString];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    if (!self.brokerKey)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, self.correlationId, @"Failed to create json for %@ class, brokerKey is nil.", self.class);
        return nil;
    }
    json[MSID_BROKER_KEY] = self.brokerKey;
    if (self.protocolVersion < 1)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, self.correlationId, @"Failed to create json for %@ class, protocolVersion is invalid.", self.class);
        return nil;
    }
    json[MSID_BROKER_PROTOCOL_VERSION_KEY] = [@(self.protocolVersion) stringValue];
    json[MSID_BROKER_CLIENT_VERSION_KEY] = self.clientVersion;
    json[MSID_BROKER_CLIENT_APP_VERSION_KEY] = self.clientAppVersion;
    json[MSID_BROKER_CLIENT_APP_NAME_KEY] = self.clientAppName;
    json[MSID_BROKER_CORRELATION_ID_KEY] = self.correlationId.UUIDString;
    
    return json;
}

@end
