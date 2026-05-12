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

#import <Foundation/Foundation.h>

@protocol MSIDRequestContext;
@class MSIDASWebAuthHandoffConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * Processes HTTP response headers for ASWebAuthenticationSession handoff instructions.
 * 
 * This class is responsible for:
 * - Detecting x-ms-aswebauth-handoff-* headers
 * - Validating handoff URLs against security allowlist
 * - Extracting handoff configuration (ephemeral mode, headers to attach)
 * - Building structured configuration objects
 *
 * Separation of concerns: This class handles header analysis/validation only.
 * Launching ASWebAuth is handled by MSIDASWebAuthSessionLauncher.
 */
@interface MSIDASWebAuthHandoffProcessor : NSObject

/**
 * Analyzes HTTP response headers for ASWebAuth handoff instructions.
 *
 * @param headers HTTP response headers from webview navigation
 * @param context Request context for logging and correlation
 * @param error Output parameter for validation errors
 * @return Handoff configuration if valid handoff detected, nil otherwise
 */
- (nullable MSIDASWebAuthHandoffConfiguration *)analyzeResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers
                                                                context:(id<MSIDRequestContext>)context
                                                                  error:(NSError *__autoreleasing*)error;

/**
 * Validates that a handoff URL meets security requirements.
 *
 * Requirements:
 * - Must be HTTPS scheme
 * - Domain must be in trusted allowlist
 *
 * @param url The handoff URL to validate
 * @param context Request context for logging
 * @param error Output parameter for validation errors
 * @return YES if valid, NO otherwise
 */
- (BOOL)validateHandoffURL:(NSURL *)url
                   context:(id<MSIDRequestContext>)context
                     error:(NSError *__autoreleasing*)error;

@end

NS_ASSUME_NONNULL_END
