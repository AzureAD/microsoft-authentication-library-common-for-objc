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
            // Sub-error keeps this distinguishable from the other parse failures in telemetry.
            XCTAssertEqual((error as NSError).userInfo[MSIDOAuthSubErrorKey] as? String, MSID_SWITCH_BROWSER_SUB_ERROR_MISSING_ACTION_URI)
        }
    }
    
    func testInit_whenNoCode_shouldReturnNil() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=some_uri")!
        
        XCTAssertThrowsError(try MSIDSwitchBrowserResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.serverInvalidResponse.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDOAuthErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "code is nil.")
            XCTAssertEqual((error as NSError).userInfo[MSIDOAuthSubErrorKey] as? String, MSID_SWITCH_BROWSER_SUB_ERROR_MISSING_CODE)
        }
    }

    // MARK: - State validation sub-errors
    //
    // A state mismatch is security-relevant: it means the response did not correspond to the request
    // this client made. Before these sub-errors it was indistinguishable from an ordinary invalid-state
    // failure in telemetry, so it could not be alerted on separately.
    //
    // validateStateParameter:expectedState:error: returns BOOL with a trailing NSError**, so Swift
    // imports it as a throwing function - success is "does not throw".

    func testValidateStateParameter_whenStateMismatches_shouldReturnMismatchSubError()
    {
        // base64url("some_other_state") decoded != "state"
        XCTAssertThrowsError(try MSIDSwitchBrowserResponse.validateStateParameter("c29tZV9vdGhlcl9zdGF0ZQ",
                                                                                 expectedState: "state")) { error in
            let e = error as NSError
            XCTAssertEqual(e.domain, MSIDOAuthErrorDomain)
            XCTAssertEqual(e.code, MSIDErrorCode.serverInvalidState.rawValue)
            XCTAssertEqual(e.userInfo[MSIDOAuthSubErrorKey] as? String, MSID_SWITCH_BROWSER_SUB_ERROR_STATE_MISMATCH)
        }
    }

    func testValidateStateParameter_whenReceivedStateMissing_shouldReturnMissingSubError()
    {
        XCTAssertThrowsError(try MSIDSwitchBrowserResponse.validateStateParameter(nil,
                                                                                 expectedState: "state")) { error in
            let e = error as NSError
            XCTAssertEqual(e.code, MSIDErrorCode.serverInvalidState.rawValue)
            // "missing" is a different operational problem from "mismatch" - one is a server/protocol
            // gap, the other is a potential response-substitution signal.
            XCTAssertEqual(e.userInfo[MSIDOAuthSubErrorKey] as? String, MSID_SWITCH_BROWSER_SUB_ERROR_STATE_MISSING)
        }
    }

    func testValidateStateParameter_whenExpectedStateMissing_shouldReturnMissingSubError()
    {
        XCTAssertThrowsError(try MSIDSwitchBrowserResponse.validateStateParameter("c3RhdGU",
                                                                                 expectedState: nil)) { error in
            let e = error as NSError
            XCTAssertEqual(e.userInfo[MSIDOAuthSubErrorKey] as? String, MSID_SWITCH_BROWSER_SUB_ERROR_STATE_MISSING)
        }
    }

    func testValidateStateParameter_whenBothStatesAbsent_shouldNotThrow()
    {
        // Pre-existing contract: no state on either side is a valid, non-erroring configuration.
        XCTAssertNoThrow(try MSIDSwitchBrowserResponse.validateStateParameter(nil, expectedState: nil))
    }

    func testValidateStateParameter_whenStateMatches_shouldNotThrow()
    {
        // base64url("state") == "state"
        XCTAssertNoThrow(try MSIDSwitchBrowserResponse.validateStateParameter("c3RhdGU", expectedState: "state"))
    }
}
