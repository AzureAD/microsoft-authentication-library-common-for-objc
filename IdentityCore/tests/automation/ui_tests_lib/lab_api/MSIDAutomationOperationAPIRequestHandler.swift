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

// MARK: - Protocols

/// Protocol for handling API responses
@objc public protocol MSIDAutomationOperationAPIResponseHandler: NSObjectProtocol {
    func response(from data: Data, error: NSErrorPointer) -> Any?
}

/// Protocol for caching API responses
@objc public protocol MSIDAutomationOperationAPICacheHandler: NSObjectProtocol {
    func cachedResponse(for request: Any) -> Any?
    func cacheResponse(_ response: Any, for request: Any)
}

// MARK: - Main Class

@objcMembers open class MSIDAutomationOperationAPIRequestHandler: NSObject {
    
    // MARK: - Properties
    
    public var apiCacheHandler: MSIDAutomationOperationAPICacheHandler?
    
    private let labAPIPath: String
    private let configurationParams: [String: Any]
    private let functionAppCodes: [String: String]?
    private let encodedCertificate: String?
    private let certificatePassword: String?
    
    // MARK: - Initialization
    
    public init(apiPath: String,
                encodedCertificate: String?,
                certificatePassword: String?,
                operationAPIConfiguration: [String: Any],
                functionAppAPIConfiguration: [String: String]?) {
        self.labAPIPath = apiPath
        self.encodedCertificate = encodedCertificate
        self.certificatePassword = certificatePassword
        self.configurationParams = operationAPIConfiguration
        self.functionAppCodes = functionAppAPIConfiguration
        super.init()
    }
    
    public convenience init(apiPath: String,
                           operationAPIConfiguration: [String: Any]) {
        self.init(apiPath: apiPath,
                 encodedCertificate: nil,
                 certificatePassword: nil,
                 operationAPIConfiguration: operationAPIConfiguration,
                 functionAppAPIConfiguration: nil)
    }
    
    // MARK: - Public API
    
    public func executeAPIRequest(_ apiRequest: MSIDAutomationBaseApiRequest,
                                  responseHandler: MSIDAutomationOperationAPIResponseHandler,
                                  completionHandler: @escaping (Any?, Error?) -> Void) {
        // Check cache first
        if let cachedResponse = apiCacheHandler?.cachedResponse(for: apiRequest) {
            DispatchQueue.main.async {
                completionHandler(cachedResponse, nil)
            }
            return
        }
        
        // Check if this request uses function app API
        if let functionCodeKey = apiRequest.functionAppCodeKey(),
           let functionAppCodes = functionAppCodes,
           let functionAppAPIPath = functionAppCodes["operation_api_path"],
           let functionCode = functionAppCodes[functionCodeKey] {
            executeFunctionAppAPIRequest(apiRequest,
                                        functionAPIPath: functionAppAPIPath,
                                        functionCode: functionCode,
                                        responseHandler: responseHandler,
                                        completionHandler: completionHandler)
            return
        }
        
        // Fall back to OAuth-based API
        getAccessTokenAndCallLabAPI(apiRequest,
                                    responseHandler: responseHandler,
                                    completionHandler: completionHandler)
    }
    
    // MARK: - OAuth Authentication
    
    private func getAccessTokenAndCallLabAPI(_ request: MSIDAutomationBaseApiRequest,
                                            responseHandler: MSIDAutomationOperationAPIResponseHandler,
                                            completionHandler: @escaping (Any?, Error?) -> Void) {
        guard let authority = configurationParams["operation_api_authority"] as? String,
              let resource = configurationParams["operation_api_resource"] as? String,
              let clientId = configurationParams["operation_api_client_id"] as? String else {
            let error = NSError(domain: "MSIDAutomationOperationAPIRequestHandler",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing required configuration parameters"])
            DispatchQueue.main.async {
                completionHandler(nil, error)
            }
            return
        }
        
        // Use certificate-based authentication if available
        if let encodedCert = encodedCertificate,
           let certPassword = certificatePassword,
           let certificateData = Data(base64Encoded: encodedCert) {
            MSIDClientCredentialHelper.getAccessToken(
                forAuthority: authority,
                resource: resource,
                clientId: clientId,
                certificate: certificateData,
                certificatePassword: certPassword
            ) { [weak self] accessToken, error in
                guard let self = self else { return }
                
                guard let token = accessToken else {
                    DispatchQueue.main.async {
                        completionHandler(nil, error)
                    }
                    return
                }
                
                self.executeAPIRequestImpl(request,
                                          responseHandler: responseHandler,
                                          accessToken: token,
                                          completionHandler: completionHandler)
            }
        } else {
            // Fall back to client secret authentication
            guard let clientSecret = configurationParams["operation_api_client_secret"] as? String else {
                let error = NSError(domain: "MSIDAutomationOperationAPIRequestHandler",
                                  code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Missing client secret"])
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                return
            }
            
            MSIDClientCredentialHelper.getAccessToken(
                forAuthority: authority,
                resource: resource,
                clientId: clientId,
                clientCredential: clientSecret
            ) { [weak self] accessToken, error in
                guard let self = self else { return }
                
                guard let token = accessToken else {
                    DispatchQueue.main.async {
                        completionHandler(nil, error)
                    }
                    return
                }
                
                self.executeAPIRequestImpl(request,
                                          responseHandler: responseHandler,
                                          accessToken: token,
                                          completionHandler: completionHandler)
            }
        }
    }
    
    // MARK: - OAuth API Request Execution
    
    private func executeAPIRequestImpl(_ request: MSIDAutomationBaseApiRequest,
                                       responseHandler: MSIDAutomationOperationAPIResponseHandler,
                                       accessToken: String,
                                       completionHandler: @escaping (Any?, Error?) -> Void) {
        guard let resultURL = request.requestURL(withAPIPath: labAPIPath) else {
            let error = NSError(domain: "MSIDAutomationOperationAPIRequestHandler",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to build API URL"])
            DispatchQueue.main.async {
                completionHandler(nil, error)
            }
            return
        }
        
        var urlRequest = URLRequest(url: resultURL)
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpMethod = request.httpMethod()
        
        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                return
            }
            
            guard (200..<300).contains(httpResponse.statusCode),
                  let data = data else {
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                return
            }
            
            var responseError: NSError?
            let result = responseHandler.response(from: data, error: &responseError)
            
            if request.shouldCacheResponse() {
                self.apiCacheHandler?.cacheResponse(result as Any, for: request)
            }
            
            DispatchQueue.main.async {
                completionHandler(result, responseError)
            }
        }.resume()
    }
    
    // MARK: - Function App API Request Execution
    
    private func executeFunctionAppAPIRequest(_ request: MSIDAutomationBaseApiRequest,
                                             functionAPIPath: String,
                                             functionCode: String,
                                             responseHandler: MSIDAutomationOperationAPIResponseHandler,
                                             completionHandler: @escaping (Any?, Error?) -> Void) {
        guard let resultURL = request.requestURL(withAPIPath: functionAPIPath, functionCode: functionCode) else {
            let error = NSError(domain: "MSIDAutomationOperationAPIRequestHandler",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to build function app API URL"])
            DispatchQueue.main.async {
                completionHandler(nil, error)
            }
            return
        }
        
        var urlRequest = URLRequest(url: resultURL)
        urlRequest.httpMethod = request.httpMethod()
        
        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                return
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                var apiError = error
                if apiError == nil {
                    var errorMessage = "Function App API request failed with status code: \(httpResponse.statusCode)"
                    if let data = data,
                       let responseBody = String(data: data, encoding: .utf8) {
                        errorMessage += "\nResponse: \(responseBody)"
                    }
                    apiError = NSError(domain: "MSIDAutomationOperationAPIRequestHandler",
                                     code: httpResponse.statusCode,
                                     userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                
                DispatchQueue.main.async {
                    completionHandler(nil, apiError)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                return
            }
            
            var responseError: NSError?
            let result = responseHandler.response(from: data, error: &responseError)
            
            if request.shouldCacheResponse() {
                self.apiCacheHandler?.cacheResponse(result as Any, for: request)
            }
            
            DispatchQueue.main.async {
                completionHandler(result, responseError)
            }
        }.resume()
    }
}
