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


#import <XCTest/XCTest.h>
#import "MSIDBrokerOperationBrowserNativeMessageRequest.h"
#import "MSIDJsonSerializableFactory.h"

@interface MSIDBrokerOperationBrowserNativeMockRequest : MSIDBaseBrokerOperationRequest <MSIDJsonSerializable>

@end

@implementation MSIDBrokerOperationBrowserNativeMockRequest

#pragma mark - MSIDBrokerOperationRequest

- (NSString *)localizedApplicationInfo
{
    return @"mock_app_info";
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    return [self init];
}

- (NSDictionary *)jsonDictionary 
{
    return @{};
}

@end

@interface MSIDBrokerOperationBrowserNativeMessageRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationBrowserNativeMessageRequestTests

- (void)setUp
{
    [MSIDJsonSerializableFactory registerClass:MSIDBrokerOperationBrowserNativeMockRequest.class forClassType:@"BrowserNativeMockRequest"];
}

- (void)tearDown
{
}

- (void)testOperation_shouldBeCorrect
{
    XCTAssertEqualObjects(@"browser_native_message_operation", [MSIDBrokerOperationBrowserNativeMessageRequest operation]);
}

- (void)testJsonDictionary_whenNoPayload_shouldBeNil
{
    __auto_type request = [MSIDBrokerOperationBrowserNativeMessageRequest new];
    request.brokerKey = @"some key";
    request.protocolVersion = 1;

    XCTAssertNil([request jsonDictionary]);
}

- (void)testJsonDictionary_whenPayloadExist_shouldBeCorrect
{
    __auto_type request = [MSIDBrokerOperationBrowserNativeMessageRequest new];
    request.payloadJson = @{@"a": @"b"};
    request.brokerKey = @"some key";
    request.protocolVersion = 1;
    request.parentProcessBundleIdentifier = @"com.qwe";
    request.parentProcessTeamId = @"12345";
    request.parentProcessLocalizedName = @"name1";

    __auto_type expectedJson = @{@"broker_key": @"some key",
                                 @"msg_protocol_ver": @"1",
                                 @"parent_process_bundle_identifier": @"com.qwe",
                                 @"parent_process_localized_name": @"name1",
                                 @"parent_process_teamId": @"12345",
                                 @"payload": @"{\"a\":\"b\"}"};
    XCTAssertEqualObjects(expectedJson, [request jsonDictionary]);
}

- (void)testInitWithJSONDictionary_whenAllValuesSet_shoudlInit
{
    __auto_type json = @{@"broker_key": @"some key",
                         @"msg_protocol_ver": @"1",
                         @"parent_process_bundle_identifier": @"com.qwe",
                         @"parent_process_teamId": @"12345",
                         @"parent_process_localized_name": @"name1",
                         @"payload": @"{\"method\":\"BrowserNativeMockRequest\"}"};
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationBrowserNativeMessageRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(request.brokerKey, @"some key");
    XCTAssertEqual(request.protocolVersion, 1);
    XCTAssertEqualObjects(request.payloadJson, @{@"method":@"BrowserNativeMockRequest"});
    XCTAssertEqualObjects(request.parentProcessBundleIdentifier, @"com.qwe");
    XCTAssertEqualObjects(request.parentProcessTeamId, @"12345");
    XCTAssertEqualObjects(request.parentProcessLocalizedName, @"name1");
    XCTAssertEqualObjects(request.callerBundleIdentifier, @"com.qwe");
    XCTAssertEqualObjects(request.callerTeamIdentifier, @"12345");
    XCTAssertEqualObjects(request.localizedCallerDisplayName, @"name1");
    XCTAssertEqualObjects(request.localizedApplicationInfo, @"mock_app_info");
    
}

- (void)testInitWithJSONDictionary_whenNoParentProcessInfo_shouldReturnNA
{
    __auto_type json = @{@"broker_key": @"some key",
                         @"msg_protocol_ver": @"1",
                         @"payload": @"{\"method\":\"GetCookies\"}"};
    
    NSError *error;
    __auto_type request = [[MSIDBrokerOperationBrowserNativeMessageRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqualObjects(request.brokerKey, @"some key");
    XCTAssertEqual(request.protocolVersion, 1);
    XCTAssertEqualObjects(request.payloadJson, @{@"method":@"GetCookies"});
    XCTAssertEqualObjects(request.callerBundleIdentifier, @"N/A");
    XCTAssertEqualObjects(request.callerTeamIdentifier, @"N/A");
    XCTAssertEqualObjects(request.localizedCallerDisplayName, @"N/A");
    XCTAssertEqualObjects(request.localizedApplicationInfo, @"N/A");
    XCTAssertNil(request.parentProcessBundleIdentifier);
    XCTAssertNil(request.parentProcessTeamId);
    XCTAssertNil(request.parentProcessLocalizedName);
}

@end
