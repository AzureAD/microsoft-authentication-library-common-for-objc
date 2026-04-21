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
#import "MSIDSystemWebViewControllerFactory.h"
#import "MSIDURLResponseHandling.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDTestSwizzle.h"

@interface MSIDTestSession: NSObject<MSIDURLResponseHandling>
@end

@implementation MSIDTestSession: NSObject
- (BOOL)handleURLResponse:(__unused NSURL *)url
{
    return YES;
}
@end

@interface MSIDTestSystemWebviewSession : NSObject<MSIDWebviewInteracting>
@end

@implementation MSIDTestSystemWebviewSession

- (void)startWithCompletionHandler:(__unused MSIDWebUICompletionHandler)completionHandler
{
}

- (void)cancelProgrammatically
{
}

- (void)dismiss
{
}

- (void)userCancel
{
}

- (NSURL *)startURL
{
    return [NSURL URLWithString:@"https://contoso.com/oauth/authorize"];
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
    [MSIDTestSwizzle reset];
    [super tearDown];
}

- (void)testInitWithStartURL_whenURLisNil_shouldFail
{
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc] initWithStartURL:nil
                                                                                   redirectURI:@"some://redirecturi"
                                                                              parentController:nil
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
    __auto_type embeddedWebviewController = [[MSIDOAuth2EmbeddedWebviewController alloc] initWithStartURL:[NSURL new]
                                                                                                   endURL:[NSURL new]
                                                                                                  webview:nil
                                                                                            customHeaders:nil
                                                                                           platfromParams:nil
                                                                                                  context:nil];
    MSIDSystemWebviewController *webVC = [MSIDSystemWebviewController new];
    [webVC setValue:embeddedWebviewController forKey:@"session"];
    [webVC setValue:[NSURL URLWithString:@"scheme://host"] forKey:@"redirectURL"];
    
    XCTAssertTrue([webVC handleURLResponse:[NSURL URLWithString:@"scheme://host"]]);
}

- (void)testInitWithAdditionalHeaders_whenInputMutableDictionaryChanges_shouldKeepCopiedHeaders
{
    NSMutableDictionary *mutableHeaders = [@{@"x-test-header" : @"value-1"} mutableCopy];
    
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc]
                                          initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                               redirectURI:@"some://redirecturi"
                                          parentController:nil
                                  useAuthenticationSession:YES
                                 allowSafariViewController:YES
                                ephemeralWebBrowserSession:NO
                                       additionalHeaders:mutableHeaders
                                               context:nil];
    
    mutableHeaders[@"x-test-header"] = @"value-2";
    NSDictionary<NSString *, NSString *> *storedHeaders = [webVC valueForKey:@"additionalHeaders"];
    
    XCTAssertEqualObjects(storedHeaders, @{@"x-test-header" : @"value-1"});
}

- (void)testStartWithCompletionHandler_whenAuthSessionUsedAndAdditionalHeadersPassed_shouldPropagateHeadersToFactory
{
    NSDictionary<NSString *, NSString *> *expectedHeaders = @{@"x-test-header" : @"value-1"};
    __block NSDictionary<NSString *, NSString *> *capturedHeaders = nil;
    
    [MSIDTestSwizzle classMethod:@selector(authSessionWithParentController:startURL:callbackScheme:useEphemeralSession:additionalHeaders:context:)
                           class:[MSIDSystemWebViewControllerFactory class]
                           block:(id)^(__unused id obj,
                                      __unused id parentController,
                                      __unused NSURL *startURL,
                                      __unused NSString *callbackScheme,
                                      __unused BOOL useEphemeralSession,
                                      NSDictionary<NSString *, NSString *> *additionalHeaders,
                                      __unused id context)
    {
        capturedHeaders = additionalHeaders;
        return [MSIDTestSystemWebviewSession new];
    }];
    
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc]
                                          initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                               redirectURI:@"some://redirecturi"
                                          parentController:nil
                                  useAuthenticationSession:YES
                                 allowSafariViewController:NO
                                ephemeralWebBrowserSession:NO
                                       additionalHeaders:expectedHeaders
                                               context:nil];
    
    [webVC startWithCompletionHandler:^(__unused NSURL *callbackURL, __unused NSError *error) {}];
    
    XCTAssertEqualObjects(capturedHeaders, expectedHeaders);
}

- (void)testStartWithCompletionHandler_whenAuthSessionUsedAndAdditionalHeadersEmpty_shouldPropagateEmptyHeadersToFactory
{
    NSDictionary<NSString *, NSString *> *expectedHeaders = @{};
    __block NSDictionary<NSString *, NSString *> *capturedHeaders = nil;
    
    [MSIDTestSwizzle classMethod:@selector(authSessionWithParentController:startURL:callbackScheme:useEphemeralSession:additionalHeaders:context:)
                           class:[MSIDSystemWebViewControllerFactory class]
                           block:(id)^(__unused id obj,
                                      __unused id parentController,
                                      __unused NSURL *startURL,
                                      __unused NSString *callbackScheme,
                                      __unused BOOL useEphemeralSession,
                                      NSDictionary<NSString *, NSString *> *additionalHeaders,
                                      __unused id context)
    {
        capturedHeaders = additionalHeaders;
        return [MSIDTestSystemWebviewSession new];
    }];
    
    MSIDSystemWebviewController *webVC = [[MSIDSystemWebviewController alloc]
                                          initWithStartURL:[NSURL URLWithString:@"https://contoso.com/oauth/authorize"]
                                               redirectURI:@"some://redirecturi"
                                          parentController:nil
                                  useAuthenticationSession:YES
                                 allowSafariViewController:NO
                                ephemeralWebBrowserSession:NO
                                       additionalHeaders:expectedHeaders
                                               context:nil];
    
    [webVC startWithCompletionHandler:^(__unused NSURL *callbackURL, __unused NSError *error) {}];
    
    XCTAssertEqualObjects(capturedHeaders, expectedHeaders);
}

@end



#endif
