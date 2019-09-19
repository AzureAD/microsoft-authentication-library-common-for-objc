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

#if !MSID_EXCLUDE_SYSTEMWV

#import <XCTest/XCTest.h>
#import "MSIDSystemWebviewController.h"
#import "MSIDURLResponseHandling.h"

@interface MSIDTestSession: NSObject<MSIDURLResponseHandling>
@end

@implementation MSIDTestSession: NSObject
- (BOOL)handleURLResponse:(NSURL *)url
{
    return YES;
}
@end

@interface MSIDSystemWebviewControllerTests : XCTestCase

@end

@implementation MSIDSystemWebviewControllerTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitWithStartURL_whenURLisNil_shouldFail
{
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc] initWithStartURL:nil
                                                                                   redirectURI:@"some://redirecturi"
                                                                              parentController:nil
                                                                              presentationType:UIModalPresentationFullScreen
                                                                      useAuthenticationSession:YES
                                                                     allowSafariViewController:YES
                                                                    ephemeralWebBrowserSession:NO
                                                                                       context:nil];
    XCTAssertNil(webVC);
}


- (void)testInitWithStartURL_whenRediectUriisNil_shouldFail
{
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc] initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                                                   redirectURI:nil
                                                                              parentController:nil
                                                                              presentationType:UIModalPresentationFullScreen
                                                                      useAuthenticationSession:YES
                                                                     allowSafariViewController:YES
                                                                    ephemeralWebBrowserSession:NO
                                                                                       context:nil];
    XCTAssertNil(webVC);

}



- (void)testInitWithStartURL_whenStartURLandCallbackURLSchemeValid_shouldSucceed
{
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc] initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                                                                   redirectURI:@"some://redirecturi"
                                                                              parentController:nil
                                                                              presentationType:UIModalPresentationFullScreen
                                                                      useAuthenticationSession:YES
                                                                     allowSafariViewController:YES
                                                                    ephemeralWebBrowserSession:NO
                                                                                       context:nil];
    XCTAssertNotNil(webVC);
    
}


- (void)testHandleURLResponse_whenRedirectSchemeMismatch_shouldReturnNo
{
    MSIDSystemWebviewController *webVC = [MSIDSystemWebviewController new];
    [webVC setValue:[NSURL URLWithString:@"scheme://host"] forKey:@"redirectURL"];
    [webVC setValue:[MSIDTestSession new] forKey:@"_session"];
    
    XCTAssertFalse([webVC handleURLResponse:[NSURL URLWithString:@"schemenotmatch://host"]]);
}

- (void)testHandleURLResponse_whenRedirectHostMismatch_shouldReturnNo
{
    MSIDSystemWebviewController *webVC = [MSIDSystemWebviewController new];
    [webVC setValue:[NSURL URLWithString:@"scheme://host"] forKey:@"redirectURL"];
    [webVC setValue:[MSIDTestSession new] forKey:@"_session"];
    
    XCTAssertFalse([webVC handleURLResponse:[NSURL URLWithString:@"scheme://hostnotmatch"]]);
}

- (void)testHandleURLResponse_whenRedirectHostAndSchemeMatch_shouldReturnYes
{
    MSIDSystemWebviewController *webVC = [MSIDSystemWebviewController new];
    [webVC setValue:[NSURL URLWithString:@"scheme://host"] forKey:@"redirectURL"];
    [webVC setValue:[MSIDTestSession new] forKey:@"_session"];
    
    XCTAssertTrue([webVC handleURLResponse:[NSURL URLWithString:@"scheme://host"]]);
}

@end



#endif
