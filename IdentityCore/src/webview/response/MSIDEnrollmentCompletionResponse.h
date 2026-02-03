//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDWebviewResponse.h"

/*!
 Response for Intune MDM enrollment completion.
 
 Returned when ASWebAuthenticationSession completes device enrollment
 and receives msauth://profileInstalled or msauth://profileComplete callback.
 
 This response indicates enrollment has completed and the auth flow should
 continue (never cancelled). For non-broker controllers on iOS, the flow
 should retry in broker context.
 */
@interface MSIDEnrollmentCompletionResponse : MSIDWebviewResponse

/*!
 The URL that triggered enrollment completion (e.g., msauth://profileInstalled).
 */
@property (nonatomic, readonly, nonnull) NSURL *profileCompletedURL;

/*!
 Indicates whether the auth flow should retry in broker context.
 
 YES for non-broker controllers on iOS (retry in broker after enrollment)
 NO for broker controllers or macOS (complete in current context)
 */
@property (nonatomic, readonly) BOOL shouldRetryInBroker;

/*!
 Creates an enrollment completion response.
 
 @param url The profileInstalled/profileComplete callback URL
 @param context Request context for logging
 @param shouldRetryInBroker Whether to retry in broker (platform-dependent)
 @param error Error if response creation fails
 */
- (instancetype _Nullable)initWithURL:(NSURL *_Nonnull)url
                              context:(id<MSIDRequestContext> _Nullable)context
                  shouldRetryInBroker:(BOOL)shouldRetryInBroker
                                error:(NSError *_Nullable __autoreleasing *_Nullable)error;

@end
