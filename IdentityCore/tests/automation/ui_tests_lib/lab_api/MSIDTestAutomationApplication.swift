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

/// Test automation application model for lab API
@objcMembers open class MSIDTestAutomationApplication: NSObject, MSIDJsonSerializable {
    
    // MARK: - Public Properties (Readonly)
    
    public private(set) var appId: String
    public private(set) var objectId: String
    public private(set) var multiTenantApp: Bool
    public private(set) var labName: String
    public private(set) var redirectUris: NSOrderedSet
    public private(set) var defaultScopes: NSOrderedSet
    public private(set) var defaultAuthorities: NSOrderedSet
    public private(set) var b2cAuthorities: [String: String]
    
    // MARK: - Public Properties (Writable)
    
    public var redirectUriPrefix: String = ""
    
    // MARK: - Computed Properties
    
    /// Returns the default redirect URI with the configured prefix
    public var defaultRedirectUri: String {
        return redirectUri(withPrefix: redirectUriPrefix)
    }
    
    // MARK: - MSIDJsonSerializable
    
    required public init(jsonDictionary json: [AnyHashable: Any]!) throws {
        // Convert AnyHashable keys to String keys
        let stringKeyedJson = json?.reduce(into: [String: Any]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = pair.value
            }
        } ?? [:]
        
        // Extract required values
        guard let appId = stringKeyedJson["appId"] as? String else {
            throw NSError(domain: MSIDErrorDomain,
                         code: MSIDErrorCode.serverInvalidResponse.rawValue,
                         userInfo: [NSLocalizedDescriptionKey: "Missing appId in application response JSON"])
        }
        
        self.appId = appId
        self.objectId = stringKeyedJson["objectId"] as? String ?? ""
        
        // Parse multi-tenant flag
        let multiTenantString = stringKeyedJson["multiTenantApp"] as? String
        self.multiTenantApp = (multiTenantString == "Yes")
        
        self.labName = stringKeyedJson["labName"] as? String ?? ""
        
        // Parse redirect URIs
        let redirectUriString = stringKeyedJson["redirectUri"] as? String ?? ""
        self.redirectUris = Self.orderedSet(fromCommaSeparated: redirectUriString)
        
        // Parse default scopes
        let defaultScopesString = stringKeyedJson["defaultScopes"] as? String
        self.defaultScopes = Self.orderedSet(fromCommaSeparated: defaultScopesString)
        
        // Parse default authorities
        let authoritiesString = stringKeyedJson["authority"] as? String
        self.defaultAuthorities = Self.orderedSet(fromCommaSeparated: authoritiesString)
        
        // Parse B2C authorities
        var parsedB2CAuthorities = [String: String]()
        
        if let b2cAuthoritiesString = stringKeyedJson["b2cAuthorities"] as? String,
           let b2cData = b2cAuthoritiesString.data(using: .utf8),
           let b2cArray = try? JSONSerialization.jsonObject(with: b2cData) as? [[String: Any]] {
            
            for b2cAuthority in b2cArray {
                if let authorityType = b2cAuthority["AuthorityType"] as? String,
                   let authority = b2cAuthority["Authority"] as? String {
                    parsedB2CAuthorities[authorityType] = authority
                }
            }
        }
        
        self.b2cAuthorities = parsedB2CAuthorities
        
        super.init()
        
        // Validate required fields
        if redirectUris.count == 0 || defaultScopes.count == 0 {
            throw NSError(domain: MSIDErrorDomain,
                         code: MSIDErrorCode.serverInvalidResponse.rawValue,
                         userInfo: [NSLocalizedDescriptionKey: "Missing parameter in application response JSON"])
        }
    }
    
    public func jsonDictionary() -> [AnyHashable: Any]! {
        return nil
    }
    
    // MARK: - Public Methods
    
    /// Returns a redirect URI with the specified prefix, or the first URI if none match
    /// - Parameter redirectPrefix: The prefix to search for
    /// - Returns: A redirect URI matching the prefix, or the first URI
    public func redirectUri(withPrefix redirectPrefix: String) -> String {
        for case let uri as String in redirectUris {
            if uri.hasPrefix(redirectPrefix) {
                return uri
            }
        }
        
        return redirectUris.firstObject as? String ?? ""
    }
    
    /// Returns the B2C authority URL for a specific policy and tenant
    /// - Parameters:
    ///   - policy: The B2C policy name
    ///   - tenantId: The tenant ID (optional)
    /// - Returns: The complete B2C authority URL, or nil if not found
    public func b2cAuthority(forPolicy policy: String, tenantId: String?) -> String? {
        guard let authority = b2cAuthorities[policy],
              let authorityURL = URL(string: authority) else {
            return nil
        }
        
        // Create B2C authority with the tenant
        let msidAuthority = MSIDB2CAuthority(url: authorityURL,
                                            validateFormat: true,
                                            rawTenant: tenantId,
                                            context: nil,
                                            error: nil)
        
        return msidAuthority?.url.absoluteString
    }
    
    // MARK: - Helper Methods
    
    /// Converts a comma-separated string into an ordered set of trimmed lowercase strings
    /// - Parameter string: The comma-separated string
    /// - Returns: An ordered set of strings
    private static func orderedSet(fromCommaSeparated string: String?) -> NSOrderedSet {
        guard let string = string else {
            return NSOrderedSet()
        }
        
        let punctuationSet = CharacterSet.punctuationCharacters
        let results = NSMutableOrderedSet()
        
        let parts = string.components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmed.isEmpty {
                let cleaned = trimmed
                    .trimmingCharacters(in: punctuationSet)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                results.add(cleaned)
            }
        }
        
        return results.copy() as! NSOrderedSet
    }
}
