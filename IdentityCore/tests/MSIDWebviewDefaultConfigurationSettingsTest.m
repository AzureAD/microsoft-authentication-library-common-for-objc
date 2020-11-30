//
//  MSIDWebviewDefaultConfigurationSettingsTest.m
//  IdentityCoreTests Mac
//
//  Created by Peter Lee on 11/30/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDWebviewUIController.h"
#import <WebKit/WebKit.h>
#import "MSIDWorkPlaceJoinConstants.h"

@interface MSIDWebviewDefaultConfigurationSettingsTest : XCTestCase

@end

@implementation MSIDWebviewDefaultConfigurationSettingsTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];

}

- (void)testMSIDWebViewUIController_MSIDWebViewShouldBeInitializedWithValidDefaultConfigSettings{
   
    WKWebViewConfiguration *defaultConfig = [MSIDWebviewUIController defaultWKWebviewConfiguration];
    WKWebView* webview = [[WKWebView alloc] initWithFrame:CGRectZero configuration:defaultConfig];
    XCTestExpectation *expectation = [self expectationWithDescription:@"retrieve userAgent String"];
    [webview evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, NSError *error) {
        NSString *userAgent = result;
        BOOL PKeyAuthNotFound = [userAgent rangeOfString:kMSIDPKeyAuthKeyWordForUserAgent].location == NSNotFound;
        XCTAssertNil(error);
#if TARGET_OS_IOS
        XCTAssertEqual(PKeyAuthNotFound,NO);
#else
        XCTAssertEqual(PKeyAuthNotFound,YES);
#endif
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
}



@end
