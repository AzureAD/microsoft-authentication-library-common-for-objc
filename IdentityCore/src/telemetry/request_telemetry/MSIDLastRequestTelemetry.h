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

#if !EXCLUDE_FROM_MSALCPP

#import <Foundation/Foundation.h>
#import "MSIDTelemetryStringSerializable.h"

@interface MSIDRequestTelemetryErrorInfo : NSObject <NSSecureCoding, NSCopying>

@property (nonatomic) NSInteger apiId;
@property (nonatomic, nullable) NSUUID *correlationId;
@property (nonatomic, nonnull) NSString *error;

@end

NS_ASSUME_NONNULL_BEGIN

@class MSIDCurrentRequestTelemetrySerializedItem;

@interface MSIDLastRequestTelemetry : NSObject <MSIDTelemetryStringSerializable, NSSecureCoding>

@property (nonatomic, readonly) NSInteger schemaVersion;
@property (nonatomic, readonly) NSInteger silentSuccessfulCount;
@property (nonatomic, nullable, readonly) NSArray<MSIDRequestTelemetryErrorInfo *> *errorsInfo;
@property (nonatomic, nullable, readonly) NSArray<NSString *> *platformFields;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedInstance;

- (void)updateWithApiId:(NSInteger)apiId
            errorString:(nullable NSString *)errorString
                context:(nullable id<MSIDRequestContext>)context;

- (void)increaseSilentSuccessfulCount;

@end

NS_ASSUME_NONNULL_END

#endif
