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

final class MSIDSwitchBrowserResponseTest: XCTestCase
{

    override func setUpWithError() throws 
    {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let flightProvider = MSIDFlightManagerMockProvider()
        flightProvider.boolForKeyContainer = [MSID_FLIGHT_SUPPORT_STATE_DUNA_CBA: true]
        MSIDFlightManager.sharedInstance().flightProvider = flightProvider
    }

    override func tearDownWithError() throws 
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInit_whenValidMsalUrl_shouldCreateObject() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil,  context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
    }
    
    func testInit_whenValidMsalUrlUpperCase_shouldCreateObject() throws
    {
        let url = URL(string: "MSAUTH.COM.MICROSOFT.msaltestapp://auth/switch_browser?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://AUTH", requestState: nil,  context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
    }
    
    func testInit_whenValidMsalUrlWithFragment_shouldCreateObject() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=some_uri&code=some_code#ff")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth#fragment", requestState: nil,  context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
    }
    
    func testInit_whenValidBrokerUrl_shouldCreateObject() throws
    {
        let url = URL(string: "msauth://broker_bundle_id//switch_browser?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth://broker_bundle_id", requestState: nil, context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
    }
    
    func testInit_whenStateIsPresentInUrl_shouldCreateObject() throws
    {
        let url = URL(string: "msauth://broker_bundle_id//switch_browser?action_uri=some_uri&code=some_code&browser_modes=AAAAAA&state=c3RhdGU")!
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth://broker_bundle_id", requestState: "state", context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.state, "c3RhdGU")
    }
    
    func testInit_whenValidBrowserMode_hasBitmaskPrivateSession_shouldBeTrue() throws
    {
        let url = URL(string: "msauth://broker_bundle_id//switch_browser?action_uri=some_uri&code=some_code&browser_modes=AQAAAA")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth://broker_bundle_id", requestState: nil, context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
        XCTAssertEqual(response?.useEphemeralWebBrowserSession, true)
    }
    
    func testInit_whenInvalidBrowserMode_hasBitmaskPrivateSession_shouldBeFalse() throws
    {
        let url = URL(string: "msauth://broker_bundle_id//switch_browser?action_uri=some_uri&code=some_code&browser_modes=AAAAAA")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth://broker_bundle_id", requestState: nil, context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
        XCTAssertEqual(response?.useEphemeralWebBrowserSession, false)
    }
    
    func testInit_whenStateIsMissingFromUrl_shouldReturnNil() throws
    {
        let url = URL(string: "msauth://broker_bundle_id//switch_browser?action_uri=some_uri&code=some_code&browser_modes=AAAAAA")!
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth://broker_bundle_id", requestState: "state", context: nil)
        
        XCTAssertNil(response)
    }
    
    func testInit_whenInvalidUrl_shouldReturnNil() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/abc?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)
        
        XCTAssertNil(response)
    }
    
    func testInit_whenInvalidSchemeInUrl_shouldReturnNil() throws
    {
        let url = URL(string: "abc.com.microsoft.msaltestapp://auth/switch_browser?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)
        
        XCTAssertNil(response)
    }
    
    func testInit_whenNoActionUri_shouldReturnNil() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser?code=some_code")!
        
        XCTAssertThrowsError(try MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.serverInvalidResponse.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDOAuthErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "action_uri is nil.")
        }
    }
    
    func testInit_whenNoCode_shouldReturnNil() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=some_uri")!
        
        XCTAssertThrowsError(try MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.serverInvalidResponse.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDOAuthErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "code is nil.")
        }
    }
}


