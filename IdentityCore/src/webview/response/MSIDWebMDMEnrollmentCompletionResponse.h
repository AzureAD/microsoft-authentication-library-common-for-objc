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

#import "MSIDWebviewResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Response object representing MDM enrollment completion callback.
 *
 * This response is triggered when user returns from MDM profile installation
 */
@interface MSIDWebMDMEnrollmentCompletionResponse : MSIDWebviewResponse

/**
 * Status of the MDM enrollment operation.
 * Possible values: "success", "check_in_timed_out"
 * Extracted from "status" query parameter.
 */
@property (nonatomic, readonly, nullable) NSString *status;


/**
 * Error URL if SSO extension is missing
 * Extracted from "errorUrl" query parameter.
 */
@property (nonatomic, readonly, nullable) NSString *errorUrl;

/**
 * Convenience property to check if enrollment completed successfully.
 * Returns YES if status is "success" or "check_in_timed_out" (case-insensitive), NO otherwise.
 */
@property (nonatomic, readonly) BOOL isSuccess;
@end

NS_ASSUME_NONNULL_END
