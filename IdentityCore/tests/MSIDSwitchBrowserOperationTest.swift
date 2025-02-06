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


import XCTest

class MSIDCertAuthManagerMock: MSIDCertAuthManager
{
    var startWithUrlInvokedCount = 0
    var startWithUrlCallbackURLToReturn: URL?
    var startWithUrlErrorToReturn: Error?
    var startURLProvidedParam: URL?
    override func start(with startURL: URL,
                        parentController parentViewController: UIViewController,
                        context: any MSIDRequestContext,
                        completionBlock: @escaping MSIDWebUICompletionHandler)
    {
        startWithUrlInvokedCount += 1
        startURLProvidedParam = startURL
        completionBlock(startWithUrlCallbackURLToReturn, startWithUrlErrorToReturn)
    }
    
    override func complete(withCallbackURL url: URL) -> Bool
    {
        return true
    }
    
    override func setRedirectUriPrefix(_ prefix: String, forScheme scheme: String) 
    {
    }
    
    var resetStateInvokedCount = 0
    override func resetState()
    {
        resetStateInvokedCount += 1
    }
}

class MSIDAuthorizeWebRequestConfigurationMock : MSIDAuthorizeWebRequestConfiguration
{
    var responseWithResultURLInvokedCount = 0
    var responseWithResultURLErrorToReturn: Error?
    var responseWithResultURLResponseToReturn = MSIDWebviewResponse()
    override func response(withResultURL url: URL, factory: MSIDWebviewFactory, context: (any MSIDRequestContext)?) throws -> MSIDWebviewResponse
    {
        responseWithResultURLInvokedCount += 1
        if let error = responseWithResultURLErrorToReturn
        {
            throw error
        }
        
        return self.responseWithResultURLResponseToReturn
    }
}

final class MSIDSwitchBrowserOperationTest: XCTestCase 
{
    lazy var validSwitchBrowserResponse: MSIDSwitchBrowserResponse? = {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=some_uri&code=some_code")!
        return try? MSIDSwitchBrowserResponse(url: url, context: nil)
    }()
    
    override func setUpWithError() throws
    {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws 
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInit_withValidResponse_shouldInit() throws
    {
        XCTAssertNotNil(self.validSwitchBrowserResponse)
        guard let response = self.validSwitchBrowserResponse else { return }
        
        let operation = try MSIDSwitchBrowserOperation(response: response)
        
        XCTAssertNotNil(operation)
    }
    
    func testInit_withInValidResponse_shouldReturnNil() throws
    {
        let response = MSIDWebviewResponse()
        XCTAssertNotNil(response)
        
        XCTAssertThrowsError(try MSIDSwitchBrowserOperation(response: response)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.internal.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "MSIDSwitchBrowserResponse is required for creating MSIDSwitchBrowserOperation")
        }
    }
    
    func testInvoke_whenCertAuthManagerReturnError_shouldReturnError() async throws
    {
        XCTAssertNotNil(self.validSwitchBrowserResponse)
        guard let response = self.validSwitchBrowserResponse else { return }
        
        let switchBrowserOperation = try MSIDSwitchBrowserOperation(response: response)
        let certAuthManagerMock = MSIDCertAuthManagerMock()
        let startWithUrlErrorToReturn = NSError(domain: "test", code: -1, userInfo: nil)
        certAuthManagerMock.startWithUrlErrorToReturn = startWithUrlErrorToReturn
        switchBrowserOperation.certAuthManager = certAuthManagerMock

        let interactiveParameters = MSIDInteractiveTokenRequestParameters()
        let webRequestConfiguration = MSIDAuthorizeWebRequestConfiguration()
        let oauth2Factory = MSIDOauth2Factory()
        
        let switchBrowserOperationInvokeExpectation = expectation(description: "switchBrowserOperationInvokeExpectation")
        
        switchBrowserOperation.invoke(with: interactiveParameters,
                                      webRequestConfiguration:webRequestConfiguration,
                                      oauthFactory: oauth2Factory,
                                      decidePolicyForBrowserActionBlock: nil)
        { response, error in
            let error = error! as NSError
            XCTAssertEqual(error, startWithUrlErrorToReturn)
            XCTAssertNil(response)
            switchBrowserOperationInvokeExpectation.fulfill()
        } authorizationCodeCompletionBlock: { result, error, wpjResponse in
            XCTFail() // this block shouldn't be called.
        }
        
        await fulfillment(of: [switchBrowserOperationInvokeExpectation], timeout: 1)
        
        XCTAssertEqual(1, certAuthManagerMock.startWithUrlInvokedCount)
        XCTAssertEqual(1, certAuthManagerMock.resetStateInvokedCount)
        XCTAssertEqual(URL(string: "some_uri?code=some_code"), certAuthManagerMock.startURLProvidedParam)
    }
    
    func testInvoke_whenWebRequestConfigurationReturnError_shouldReturnError() async throws
    {
        XCTAssertNotNil(self.validSwitchBrowserResponse)
        guard let response = self.validSwitchBrowserResponse else { return }
        
        let switchBrowserOperation = try MSIDSwitchBrowserOperation(response: response)
        let certAuthManagerMock = MSIDCertAuthManagerMock()
        certAuthManagerMock.startWithUrlCallbackURLToReturn = URL(string: "app_redirect_uri?code=some_code&action=some_action")
        switchBrowserOperation.certAuthManager = certAuthManagerMock

        let interactiveParameters = MSIDInteractiveTokenRequestParameters()
        let webRequestConfigurationMock = MSIDAuthorizeWebRequestConfigurationMock()
        let responseWithResultURLErrorToReturn = NSError(domain: "test", code: -2, userInfo: nil)
        webRequestConfigurationMock.responseWithResultURLErrorToReturn = responseWithResultURLErrorToReturn
        let oauth2Factory = MSIDOauth2Factory()
        
        let switchBrowserOperationInvokeExpectation = expectation(description: "switchBrowserOperationInvokeExpectation")
        
        switchBrowserOperation.invoke(with: interactiveParameters,
                                      webRequestConfiguration:webRequestConfigurationMock,
                                      oauthFactory: oauth2Factory,
                                      decidePolicyForBrowserActionBlock: nil)
        { response, error in
            let error = error! as NSError
            XCTAssertEqual(error, responseWithResultURLErrorToReturn)
            XCTAssertNil(response)
            switchBrowserOperationInvokeExpectation.fulfill()
        } authorizationCodeCompletionBlock: { result, error, wpjResponse in
            XCTFail() // this block shouldn't be called.
        }
        
        await fulfillment(of: [switchBrowserOperationInvokeExpectation], timeout: 1)
        
        XCTAssertEqual(1, certAuthManagerMock.startWithUrlInvokedCount)
        XCTAssertEqual(1, certAuthManagerMock.resetStateInvokedCount)
        XCTAssertEqual(URL(string: "some_uri?code=some_code"), certAuthManagerMock.startURLProvidedParam)
        XCTAssertEqual(1, webRequestConfigurationMock.responseWithResultURLInvokedCount)
    }
    
    func testInvoke_whenWebResponseCreaated_shouldReturnResponse() async throws
    {
        XCTAssertNotNil(self.validSwitchBrowserResponse)
        guard let response = self.validSwitchBrowserResponse else { return }
        
        let switchBrowserOperation = try MSIDSwitchBrowserOperation(response: response)
        let certAuthManagerMock = MSIDCertAuthManagerMock()
        certAuthManagerMock.startWithUrlCallbackURLToReturn = URL(string: "app_redirect_uri?code=some_code&action=some_action")
        switchBrowserOperation.certAuthManager = certAuthManagerMock

        let interactiveParameters = MSIDInteractiveTokenRequestParameters()
        let webRequestConfigurationMock = MSIDAuthorizeWebRequestConfigurationMock()
        let oauth2Factory = MSIDOauth2Factory()
        
        let switchBrowserOperationInvokeExpectation = expectation(description: "switchBrowserOperationInvokeExpectation")
        
        switchBrowserOperation.invoke(with: interactiveParameters,
                                      webRequestConfiguration:webRequestConfigurationMock,
                                      oauthFactory: oauth2Factory,
                                      decidePolicyForBrowserActionBlock: nil)
        { response, error in
            XCTAssertEqual(response, webRequestConfigurationMock.responseWithResultURLResponseToReturn)
            XCTAssertNil(error)
            switchBrowserOperationInvokeExpectation.fulfill()
        } authorizationCodeCompletionBlock: { result, error, wpjResponse in
            XCTFail() // this block shouldn't be called.
        }
        
        await fulfillment(of: [switchBrowserOperationInvokeExpectation], timeout: 1)
        
        XCTAssertEqual(1, certAuthManagerMock.startWithUrlInvokedCount)
        XCTAssertEqual(1, certAuthManagerMock.resetStateInvokedCount)
        XCTAssertEqual(URL(string: "some_uri?code=some_code"), certAuthManagerMock.startURLProvidedParam)
        XCTAssertEqual(1, webRequestConfigurationMock.responseWithResultURLInvokedCount)
    }
}
