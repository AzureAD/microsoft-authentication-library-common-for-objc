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

import Foundation

// MARK: - String Constants (Objective-C Compatible)

/// Test app type constants
@objcMembers public class MSIDTestAppType: NSObject {
    public static let cloud = "cloud"
    public static let onPrem = "onprem"
}

/// Test app environment constants
@objcMembers public class MSIDTestAppEnvironment: NSObject {
    public static let wwCloud = "azurecloud"
    public static let chinaCloud = "azurechinacloud"
    public static let germanCloud = "azuregermanycloud"
    public static let usGovCloud = "azureusgovernment"
    public static let azureB2C = "azureb2ccloud"
    public static let ppeCloud = "azureppe"
}

/// Test app audience constants
@objcMembers public class MSIDTestAppAudience: NSObject {
    public static let myOrg = "azureadmyorg"
    public static let multipleOrgs = "azureadmultipleorgs"
    public static let multipleOrgsAndPersonalAccounts = "azureadandpersonalmicrosoftaccount"
}

/// Test app whitelist type constants
@objcMembers public class MSIDTestAppWhiteListType: NSObject {
    public static let mamca = "app_whitelist_mamca"
    public static let foci = "app_whitelist_foci"
}

// MARK: - Main Class

@objcMembers open class MSIDTestAutomationAppConfigurationRequest: MSIDAutomationBaseApiRequest {
    
    // MARK: - Properties
    
    public var testAppType: String = MSIDTestAppType.cloud
    public var testAppEnvironment: String = MSIDTestAppEnvironment.wwCloud
    public var testAppAudience: String = MSIDTestAppAudience.multipleOrgsAndPersonalAccounts
    public var additionalQueryParameters: [String: String]?
    public var appWhiteListType: String?
    public var appId: String?
    
    // MARK: - Initialization
    
    public required init() {
        super.init()
    }
    
    // MARK: - NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let request = type(of: self).init()
        request.testAppType = testAppType
        request.testAppEnvironment = testAppEnvironment
        request.testAppAudience = testAppAudience
        request.additionalQueryParameters = additionalQueryParameters
        request.appWhiteListType = appWhiteListType
        request.appId = appId
        return request
    }
    
    // MARK: - Base Request Override
    
    open override func requestOperationPath() -> String? {
        // If appID is present, append it to path to ensure querying specific apps results in going to the correct path
        if let appId = appId {
            return "app/\(appId)"
        }
        return "App"
    }
    
    open override func queryItems() -> [URLQueryItem]? {
        var queryItems = [
            URLQueryItem(name: "apptype", value: testAppType),
            URLQueryItem(name: "azureenvironment", value: testAppEnvironment),
            URLQueryItem(name: "signinaudience", value: testAppAudience)
        ]
        
        // Add whitelist type if present
        if let whiteListType = appWhiteListType {
            queryItems.append(URLQueryItem(name: "app_whitelist_type", value: whiteListType))
        }
        
        // Add additional query parameters
        if let additionalParams = additionalQueryParameters {
            for (key, value) in additionalParams {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
        }
        
        return queryItems
    }
    
    open override func shouldCacheResponse() -> Bool {
        return true
    }
    
    // MARK: - Factory Method
    
    open override class func request(with dictionary: [String: Any]) -> MSIDAutomationBaseApiRequest? {
        let request = MSIDTestAutomationAppConfigurationRequest()
        
        if let typeString = dictionary["test_app_type"] as? String {
            request.testAppType = typeString
        }
        
        if let envString = dictionary["test_app_environment"] as? String {
            request.testAppEnvironment = envString
        }
        
        if let audienceString = dictionary["test_app_audience"] as? String {
            request.testAppAudience = audienceString
        }
        
        if let whiteListString = dictionary["app_whitelist_type"] as? String {
            request.appWhiteListType = whiteListString
        }
        
        return request
    }
}
