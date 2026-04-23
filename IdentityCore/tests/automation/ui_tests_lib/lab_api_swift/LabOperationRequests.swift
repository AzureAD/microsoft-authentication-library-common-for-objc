// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

// MARK: - Reset Request

/// Request to reset a test account (e.g., password reset).
public struct LabResetRequest: LabAPIRequest {
    public typealias ResponseType = LabOperationResult

    public var operation: ResetOperation
    public var upn: String

    public var path: String { "Reset" }
    public var httpMethod: HTTPMethod { .post }
    public var apiTarget: APITarget { .functionApp }

    public var queryParameters: [URLQueryItem] {
        [
            URLQueryItem(name: "operation", value: operation.rawValue),
            URLQueryItem(name: "upn", value: upn),
        ]
    }

    public init(operation: ResetOperation, upn: String) {
        self.operation = operation
        self.upn = upn
    }
}

// MARK: - Temporary Account Request

/// Request to create a temporary test account.
public struct LabTempAccountRequest: LabAPIRequest {
    public typealias ResponseType = [LabTestAccount]

    public var accountType: TemporaryAccountType

    public var path: String { "CreateTempUser" }
    public var httpMethod: HTTPMethod { .post }
    public var apiTarget: APITarget { .functionApp }

    public var queryParameters: [URLQueryItem] {
        [URLQueryItem(name: "usertype", value: accountType.rawValue)]
    }

    public init(accountType: TemporaryAccountType) {
        self.accountType = accountType
    }
}

// MARK: - Delete Device Request

/// Request to delete a test device from the Lab.
public struct LabDeleteDeviceRequest: LabAPIRequest {
    public typealias ResponseType = LabOperationResult

    public var upn: String
    public var deviceId: String

    public var path: String { "DeleteDevice" }
    public var httpMethod: HTTPMethod { .post }
    public var apiTarget: APITarget { .functionApp }

    public var queryParameters: [URLQueryItem] {
        [
            URLQueryItem(name: "upn", value: upn),
            URLQueryItem(name: "deviceid", value: deviceId),
        ]
    }

    public init(upn: String, deviceId: String) {
        self.upn = upn
        self.deviceId = deviceId
    }
}

// MARK: - Policy Toggle Request

/// Request to enable or disable a policy for a test account.
public struct LabPolicyToggleRequest: LabAPIRequest {
    public typealias ResponseType = LabOperationResult

    public var upn: String
    public var policyType: String
    public var enabled: Bool

    public var path: String { "PolicyToggle" }
    public var httpMethod: HTTPMethod { .post }
    public var apiTarget: APITarget { .functionApp }

    public var queryParameters: [URLQueryItem] {
        [
            URLQueryItem(name: "upn", value: upn),
            URLQueryItem(name: "policytype", value: policyType),
            URLQueryItem(name: "enabled", value: enabled ? "true" : "false"),
        ]
    }

    public init(upn: String, policyType: String, enabled: Bool) {
        self.upn = upn
        self.policyType = policyType
        self.enabled = enabled
    }
}

// MARK: - Operation Result

/// Generic result from Lab API mutation operations.
public struct LabOperationResult: Codable, Sendable {
    public let result: String?
    public let message: String?

    public var isSuccess: Bool {
        result?.lowercased() != "errors"
    }
}
