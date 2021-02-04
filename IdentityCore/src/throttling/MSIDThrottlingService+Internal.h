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

#import "MSIDThrottlingService.h"
#import "MSIDLastRequestTelemetry.h"

@interface MSIDThrottlingService ()
NS_ASSUME_NONNULL_BEGIN

@property (nonatomic) MSIDLastRequestTelemetry *lastRequestTelemetry;
@property id<MSIDRequestContext> context;

- (MSIDThrottlingType)getThrottleTypeFrom:(id<MSIDThumbprintCalculatable> _Nonnull)request
                            errorResponse:(NSError *)errorResponse
                          isSSOExtRequest:(BOOL)isSSOExtRequest
                                    error:(NSError *_Nullable *_Nullable)error;

- (MSIDThrottlingType)isResponse429ThrottleTypeWithErrorResponse:(NSError * _Nullable)errorResponse
                                                 isSSOExtRequest:(BOOL)isSSOExtRequest
                                                           error:(NSError *_Nullable *_Nullable)error;

- (MSIDThrottlingType)isResponseUIRequiredThrottleType:(NSError *)errorResponse;

- (BOOL)is429ThrottleType:(id<MSIDThumbprintCalculatable> _Nonnull)request
              resultBlock:(nonnull MSIDThrottleResultBlock)resultBlock;

- (BOOL)isUIRequiredThrottleType:(id<MSIDThumbprintCalculatable> _Nonnull)request
                     resultBlock:(nonnull MSIDThrottleResultBlock)resultBlock;

- (void)createDBRecordAndUpdateWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                             errorResponse:(NSError * _Nullable)errorResponse
                           isSSOExtRequest:(BOOL)isSSOExtRequest
                              throttleType:(MSIDThrottlingType)throttleType
                               returnError:(NSError *_Nullable *_Nullable)error;

- (void)updateServerTelemetry:(MSIDThrottlingCacheRecord *)cacheRecord;

- (NSDate *)getRetryDateFromErrorResponse:(NSError * _Nullable)errorResponse;

+ (BOOL)validateInput:(id<MSIDThumbprintCalculatable> _Nonnull)request;

+ (NSDate *)getLastRefreshTimeWithContext:(id<MSIDRequestContext> _Nullable)context
                                    error:(NSError *_Nullable *_Nullable)error;

NS_ASSUME_NONNULL_END
@end
