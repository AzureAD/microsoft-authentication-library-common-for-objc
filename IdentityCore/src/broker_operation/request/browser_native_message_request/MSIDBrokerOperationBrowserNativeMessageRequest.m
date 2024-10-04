//
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


#import "MSIDBrokerOperationBrowserNativeMessageRequest.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDJsonSerializableFactory.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDBrowserNativeMessageRequest.h"

NSString *const MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY = @"payload";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_REQUEST_METHOD_KEY = @"method";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPTID_KEY = @"parent_process_teamId";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPBI_KEY = @"parent_process_bundle_identifier";
NSString *const MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPLN_KEY = @"parent_process_localized_name";

@implementation MSIDBrokerOperationBrowserNativeMessageRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
}

- (NSString *)method
{
    return self.payloadJson[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_METHOD_KEY];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_BROWSER_NATIVE_MESSAGE;
}

- (NSString *)callerBundleIdentifier
{
    return self.parentProcessBundleIdentifier ?: NSLocalizedString(@"N/A", nil);
}

- (NSString *)callerTeamIdentifier
{
    return self.parentProcessTeamId ?: NSLocalizedString(@"N/A", nil);
}

- (NSString *)localizedCallerDisplayName
{
    return self.parentProcessLocalizedName ?: NSLocalizedString(@"N/A", nil);
}

- (NSString *)localizedApplicationInfo
{
    NSString *method = self.payloadJson[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_METHOD_KEY];
    MSIDBrowserNativeMessageRequest *brokerOperationRequest = [MSIDJsonSerializableFactory createFromJSONDictionary:self.payloadJson
                                                                          classType:method
                                                                  assertKindOfClass:MSIDBrowserNativeMessageRequest.class
                                                                              error:nil];
    
    if (![NSString msidIsStringNilOrBlank:brokerOperationRequest.localizedApplicationInfo])
    {
        return brokerOperationRequest.localizedApplicationInfo;
    }
    
    return NSLocalizedString(@"N/A", nil);
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY required:YES error:error]) return nil;
        NSString *payload = json[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY];
        
        _payloadJson = [NSDictionary msidDictionaryFromJSONString:payload];
        if (!_payloadJson)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize payload.", nil, nil, nil, nil, nil, YES);
            }
            
            return nil;
        }
        
        if (!_payloadJson[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_METHOD_KEY])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Payload is invalid: no 'method' found.", nil, nil, nil, nil, nil, YES);
            }
            
            return nil;
        }
        
        _parentProcessTeamId = [json msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPTID_KEY];
        _parentProcessBundleIdentifier = [json msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPBI_KEY];
        _parentProcessLocalizedName = [json msidStringObjectForKey:MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPLN_KEY];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    if (!self.payloadJson) return nil;
    
    json[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PAYLOAD_KEY] = [self.payloadJson msidJSONSerializeWithContext:nil];
    
    json[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPTID_KEY] = self.parentProcessTeamId;
    json[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPBI_KEY] = self.parentProcessBundleIdentifier;
    json[MSID_BROWSER_NATIVE_MESSAGE_REQUEST_PPLN_KEY] = self.parentProcessLocalizedName;
    
    return json;
}

@end
