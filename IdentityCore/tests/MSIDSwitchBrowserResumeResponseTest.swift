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

final class MSIDSwitchBrowserResumeResponseTest: XCTestCase 
{
    override func setUpWithError() throws 
    {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws 
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInit_whenValidMsalUrl_shouldCreateObject() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser_resume?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResumeResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
    }
    
    func testInit_whenValidBrokerUrl_shouldCreateObject() throws
    {
        let url = URL(string: "msauth://broker_bundle_id//switch_browser_resume?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResumeResponse(url: url, redirectUri: "msauth://broker_bundle_id", requestState: nil, context: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.actionUri, "some_uri")
        XCTAssertEqual(response?.switchBrowserSessionToken, "some_code")
    }
    
    func testInit_whenInvalidUrl_shouldReturnNil() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/abc?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResumeResponse(url: url, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)
        
        XCTAssertNil(response)
    }
    
    func testInit_whenInvalidSchemeInUrl_shouldReturnNil() throws
    {
        let url = URL(string: "abc.com.microsoft.msaltestapp://auth/switch_browser_resume?action_uri=some_uri&code=some_code")!
        
        let response = try? MSIDSwitchBrowserResumeResponse(url: url, redirectUri: "qwe://auth", requestState: nil, context: nil)
        
        XCTAssertNil(response)
    }
    
    func testInit_whenNoActionUri_shouldReturnNil() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser_resume?code=some_code")!
        
        XCTAssertThrowsError(try MSIDSwitchBrowserResumeResponse(url: url, redirectUri:"msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.serverInvalidResponse.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDOAuthErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "action_uri is nil.")
        }
    }
    
    func testInit_whenNoCode_shouldReturnNil() throws
    {
        let url = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser_resume?action_uri=some_uri")!
        
        XCTAssertThrowsError(try MSIDSwitchBrowserResumeResponse(url: url, redirectUri:"msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.serverInvalidResponse.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDOAuthErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "code is nil.")
        }
    }

}
