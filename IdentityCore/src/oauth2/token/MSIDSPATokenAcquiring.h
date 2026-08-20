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
@class MSIDBrowserNativeMessageGetTokenRequest;
@class MSIDInteractiveTokenRequestParameters;
@class MSIDSPATokenAcquisitionResult;
@protocol MSIDRequestContext;
NS_ASSUME_NONNULL_BEGIN
typedef void (^MSIDSPATokenAcquirerCompletionBlock)(MSIDSPATokenAcquisitionResult *_Nullable result,
                                                     NSError *_Nullable error);
/// Completion blocks must be invoked exactly once and may run synchronously or asynchronously on an arbitrary queue.
@protocol MSIDSPATokenAcquiring <NSObject>
/// Returns nil only after populating error.
- (nullable MSIDInteractiveTokenRequestParameters *)requestParametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                                        context:(nullable id<MSIDRequestContext>)context
                                                                          error:(NSError *_Nullable *_Nullable)error;
- (void)acquireSilentWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                            request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(nullable id<MSIDRequestContext>)context
                    completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock;
- (void)acquireInteractiveWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                context:(nullable id<MSIDRequestContext>)context
                        completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock;
@end
NS_ASSUME_NONNULL_END
