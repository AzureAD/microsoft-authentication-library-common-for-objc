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

final class MSIDSwitchBrowserResumeOperationTest: XCTestCase 
{
    lazy var validSwitchBrowserResumeResponse: MSIDSwitchBrowserResumeResponse? = {
        
        let switchUrl = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=some_uri&code=some_code")!
        let switchBrowserResponse = try? MSIDSwitchBrowserResponse(url: switchUrl, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil,  context: nil)
        
        let resumeUrl = URL(string: "msauth.com.microsoft.msaltestapp://auth/switch_browser_resume?action_uri=some_uri&code=some_code")!
        let resumeResponse = try? MSIDSwitchBrowserResumeResponse(url: resumeUrl, redirectUri: "msauth.com.microsoft.msaltestapp://auth", requestState: nil, context: nil)
        resumeResponse?.parent = switchBrowserResponse
        
        return resumeResponse
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
        XCTAssertNotNil(self.validSwitchBrowserResumeResponse)
        guard let response = self.validSwitchBrowserResumeResponse else { return }
        
        let operation = try MSIDSwitchBrowserResumeOperation(response: response)
        
        XCTAssertNotNil(operation)
    }
    
    func testInit_whenNoParentResponse_shouldReturnNil() throws
    {
        XCTAssertNotNil(self.validSwitchBrowserResumeResponse)
        guard let response = self.validSwitchBrowserResumeResponse else { return }
        response.parent = nil
        
        XCTAssertThrowsError(try MSIDSwitchBrowserResumeOperation(response: response)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.internal.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "Parent response of type MSIDSwitchBrowserResponse is required for creating MSIDSwitchBrowserResumeOperation")
        }
    }

    func testInit_withInValidResponse_shouldReturnNil() throws
    {
        let response = MSIDWebviewResponse()
        XCTAssertNotNil(response)
        
        XCTAssertThrowsError(try MSIDSwitchBrowserResumeOperation(response: response)) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.internal.rawValue)
            XCTAssertEqual((error as NSError).domain, MSIDErrorDomain)
            XCTAssertEqual((error as NSError).userInfo["MSIDErrorDescriptionKey"] as? String, "MSIDSwitchBrowserResumeResponse is required for creating MSIDSwitchBrowserResumeOperation")
        }
    }
}
