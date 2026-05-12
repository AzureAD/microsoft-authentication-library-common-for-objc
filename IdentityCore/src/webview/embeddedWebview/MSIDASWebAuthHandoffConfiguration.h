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
#import "MSIDConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Configuration object for ASWebAuthenticationSession handoff.
 * Contains all parameters extracted from x-ms-aswebauth-handoff-* headers.
 */
@interface MSIDASWebAuthHandoffConfiguration : NSObject

/**
 * The URL to load in ASWebAuthenticationSession.
 * Extracted from x-ms-aswebauth-handoff-url header.
 */
@property (nonatomic, readonly) NSURL *handoffURL;

/**
 * Whether to use ephemeral session (no cookies/cache).
 * Extracted from x-ms-aswebauth-handoff-use-ephemeral-session header.
 * Defaults to YES if header not present.
 */
@property (nonatomic, readonly) BOOL useEphemeralSession;

/**
 * Purpose/context for the system webview session.
 * Determines callback URL validation and handling.
 */
@property (nonatomic, readonly) MSIDSystemWebviewPurpose purpose;

/**
 * Additional HTTP headers to include in ASWebAuth session.
 * Extracted from x-ms-aswebauth-handoff-attach-headers header.
 * Only includes headers with x-ms-aswebauth-handoff- prefix for security.
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *additionalHeaders;

/**
 * Initialize handoff configuration.
 *
 * @param url Handoff URL to load
 * @param useEphemeral Whether to use ephemeral session
 * @param purpose Purpose of the system webview
 * @param headers Additional headers to attach
 * @return Initialized configuration
 */
- (instancetype)initWithHandoffURL:(NSURL *)url
                useEphemeralSession:(BOOL)useEphemeral
                            purpose:(MSIDSystemWebviewPurpose)purpose
                  additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)headers NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
