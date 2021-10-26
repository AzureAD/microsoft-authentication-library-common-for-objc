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
#import "MSIDBrokerOperationGetSsoCookiesResponse.h"
#import "MSIDBrokerConstants.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"

@interface MSIDBrokerOperationGetSsoCookiesResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetSsoCookiesResponseTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInitWithJSONDictionary_whenJsonValid_shouldReturnValidResult {
    
    NSDictionary *ssoCookies =
    @{
        @"prt_headers":
            @[
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential1": @"Base 64 Encoded JWT1"},
                  @"home_account_id": @"uid.utid1",
                  @"displayable_id": @"demo1@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential2": @"Base 64 Encoded JWT2"},
                  @"home_account_id": @"uid.utid2",
                  @"displayable_id": @"demo2@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential3": @"Base 64 Encoded JWT3"},
                  @"home_account_id": @"uid.utid3",
                  @"displayable_id":@"demo3@contoso.com"
              }
            ],
         @"device_headers":
            @[
               @{
                  @"header": @{@"x-ms-DeviceCredential1": @"Base 64 Encoded JWT1"},
                  @"tenant_id": @"tenantId1",
               },
               @{
                  @"header": @{@"x-ms-DeviceCredential2": @"Base 64 Encoded JWT2"},
                  @"tenant_id": @"tenantId2",
               }
            ]
    };
    
    NSString *ssoCookiesJsonString = [ssoCookies msidJSONSerializeWithContext:nil];
    
    NSDictionary *json = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @1,
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies" : ssoCookiesJsonString
    };
    
    NSError *error;
    MSIDBrokerOperationGetSsoCookiesResponse *response = [[MSIDBrokerOperationGetSsoCookiesResponse alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(response.success, YES);
    XCTAssertEqual(response.prtHeaders.count, 3);
    XCTAssertEqual(response.deviceHeaders.count, 2);
    XCTAssertTrue([ssoCookiesJsonString isEqualToString:response.jsonDictionary[@"sso_cookies"]]);
}

- (void)testInitWithJSONDictionary_whenJsonValid_EmptyDeviceHeader_shouldReturnValidResult {
    
    NSDictionary *ssoCookies =
    @{
        @"prt_headers":
            @[
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential1": @"Base 64 Encoded JWT1"},
                  @"home_account_id": @"uid.utid1",
                  @"displayable_id": @"demo1@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential2": @"Base 64 Encoded JWT2"},
                  @"home_account_id": @"uid.utid2",
                  @"displayable_id": @"demo2@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential3": @"Base 64 Encoded JWT3"},
                  @"home_account_id": @"uid.utid3",
                  @"displayable_id":@"demo3@contoso.com"
              }
            ],
         @"device_headers":@[]
    };
    
    NSString *ssoCookiesJsonString = [ssoCookies msidJSONSerializeWithContext:nil];
    
    NSDictionary *json = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @1,
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies" : ssoCookiesJsonString
    };
    
    NSError *error;
    MSIDBrokerOperationGetSsoCookiesResponse *response = [[MSIDBrokerOperationGetSsoCookiesResponse alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(response.success, YES);
    XCTAssertEqual(response.prtHeaders.count, 3);
    XCTAssertEqual(response.deviceHeaders.count, 0);
}

- (void)testInitWithJSONDictionary_whenJsonValid_EmptyDeviceHeader_oneMissingAccounIdentifier_oneNoAccountIdentifier_shouldReturnValidResult {
    
    NSDictionary *ssoCookies =
    @{
        @"prt_headers":
            @[
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential1": @"Base 64 Encoded JWT1"},
                  @"home_account_id": @"uid.utid1",
                  @"displayable_id": @"demo1@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential2": @"Base 64 Encoded JWT2"},
                  @"displayable_id": @"demo2@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential3": @"Base 64 Encoded JWT3"},
                  @"home_account_id": @"",
                  @"displayable_id":@"demo3@contoso.com"
              }
            ],
         @"device_headers":@[]
    };
    
    NSString *ssoCookiesJsonString = [ssoCookies msidJSONSerializeWithContext:nil];
    
    NSDictionary *json = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @1,
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies" : ssoCookiesJsonString
    };
    
    NSError *error;
    MSIDBrokerOperationGetSsoCookiesResponse *response = [[MSIDBrokerOperationGetSsoCookiesResponse alloc] initWithJSONDictionary:json error:&error];
    XCTAssertEqual(response.success, YES);
    XCTAssertEqual(response.prtHeaders.count, 3);
    XCTAssertNil(response.deviceHeaders);
}

- (void)testInitWithJSONDictionary_whenJsonValid_EmptyPrtHeader_shouldReturnValidResult {
    
    NSDictionary *ssoCookies =
    @{
        @"prt_headers":
            @[],
         @"device_headers":
            @[
               @{
                  @"header": @{@"x-ms-DeviceCredential1": @"Base 64 Encoded JWT1"},
                  @"tenant_id": @"tenantId1",
               },
               @{
                  @"header": @{@"x-ms-DeviceCredential2": @"Base 64 Encoded JWT2"},
                  @"tenant_id": @"tenantId2",
               }
            ]
    };
    
    NSString *ssoCookiesJsonString = [ssoCookies msidJSONSerializeWithContext:nil];
    
    NSDictionary *json = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @1,
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies" : ssoCookiesJsonString
    };
    
    NSError *error;
    MSIDBrokerOperationGetSsoCookiesResponse *response = [[MSIDBrokerOperationGetSsoCookiesResponse alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(response.success, YES);
    XCTAssertEqual(response.prtHeaders.count, 0);
    XCTAssertEqual(response.deviceHeaders.count, 2);
}

- (void)testInitWithJSONDictionary_whenJsonValid_emptyPrtHeader_oneMissingTenantId_oneNoTenantId_shouldValidResult {
    
    NSDictionary *ssoCookies =
    @{
        @"prt_headers":
            @[],
         @"device_headers":
            @[
               @{
                  @"header": @{@"x-ms-DeviceCredential1": @"Base 64 Encoded JWT1"},
                  @"tenant_id": @"tenantId1",
               },
               @{
                  @"header": @{@"x-ms-DeviceCredential2": @"Base 64 Encoded JWT2"},
                  @"tenant_id": @"",
               },
               @{
                  @"header": @{@"x-ms-DeviceCredential3": @"Base 64 Encoded JWT3"},
               }
            ]
    };
    
    NSString *ssoCookiesJsonString = [ssoCookies msidJSONSerializeWithContext:nil];
    
    NSDictionary *json = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @0,
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies" : ssoCookiesJsonString
    };
    
    NSError *error;
    MSIDBrokerOperationGetSsoCookiesResponse *response = [[MSIDBrokerOperationGetSsoCookiesResponse alloc] initWithJSONDictionary:json error:&error];
    XCTAssertEqual(response.success, NO);
    XCTAssertNil(response.prtHeaders);
    XCTAssertEqual(response.prtHeaders.count, 0);
    XCTAssertEqual(response.deviceHeaders.count, 3);
}

@end
