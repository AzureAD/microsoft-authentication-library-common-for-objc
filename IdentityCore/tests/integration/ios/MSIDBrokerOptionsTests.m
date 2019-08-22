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
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDApplicationTestUtil.h"

@interface MSIDBrokerOptionsTests : XCTestCase

@end

@implementation MSIDBrokerOptionsTests

- (void)tearDown
{
    MSIDApplicationTestUtil.canOpenURLSchemes = nil;
    [super tearDown];
}

- (void)testInit_whenDefaultRequiredBroker_customSchemeProtocol_andAADV2Request
{
    MSIDBrokerInvocationOptions *options = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault protocolType:MSIDBrokerProtocolTypeCustomScheme aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    
    XCTAssertNotNil(options);
    XCTAssertEqual(options.minRequiredBrokerType, MSIDRequiredBrokerTypeDefault);
    XCTAssertEqual(options.protocolType, MSIDBrokerProtocolTypeCustomScheme);
    XCTAssertEqual(options.brokerAADRequestVersion, MSIDBrokerAADRequestVersionV2);
    XCTAssertEqualObjects(options.brokerBaseUrlString, @"msauthv2://broker");
    XCTAssertFalse(options.isUniversalLink);
}

- (void)testInit_whenDefaultRequiredBroker_universalSchemeProtocol_andAADV1Request
{
    MSIDBrokerInvocationOptions *options = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault protocolType:MSIDBrokerProtocolTypeUniversalLink aadRequestVersion:MSIDBrokerAADRequestVersionV1];
    
    XCTAssertNotNil(options);
    XCTAssertEqual(options.minRequiredBrokerType, MSIDRequiredBrokerTypeDefault);
    XCTAssertEqual(options.protocolType, MSIDBrokerProtocolTypeUniversalLink);
    XCTAssertEqual(options.brokerAADRequestVersion, MSIDBrokerAADRequestVersionV1);
    XCTAssertEqualObjects(options.brokerBaseUrlString, @"https://login.microsoftonline.com/applebroker/msauth");
    XCTAssertTrue(options.isUniversalLink);
}

- (void)testCanUseBroker_wheniOS13AndOldBrokerInstalled_andAADV2RequestVersion_shouldReturnFalse
{
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2"];
    
    MSIDBrokerInvocationOptions *options = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeWithNonceSupport
                                                                                              protocolType:MSIDBrokerProtocolTypeUniversalLink
                                                                                         aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    
    BOOL result = [options isRequiredBrokerPresent];
    XCTAssertFalse(result);
}

- (void)testCanUseBroker_wheniOS13AndNewBrokerInstalled_andAADV1RequestVersion_shouldReturnFalse
{
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauth", @"msauthv3"];
    
    MSIDBrokerInvocationOptions *options = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeWithNonceSupport
                                                                                              protocolType:MSIDBrokerProtocolTypeUniversalLink
                                                                                         aadRequestVersion:MSIDBrokerAADRequestVersionV1];
    
    BOOL result = [options isRequiredBrokerPresent];
    XCTAssertTrue(result);
}

@end
