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
#import "MSIDJsonSerializable.h"

@class MSIDDeviceInfo;

extern NSString * _Nonnull const MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationResponse : NSObject <MSIDJsonSerializable>

@property (nonatomic, class, readonly) NSString *responseType;

@property (nonatomic) NSString *operation;
@property (nonatomic) BOOL success;
@property (nonatomic, nullable) NSString *clientAppVersion;

@property (nonatomic) MSIDDeviceInfo *deviceInfo;

@property (nonatomic) NSNumber *httpStatusCode;
@property (nonatomic, nullable) NSDictionary *httpHeaders;
@property (nonatomic) NSString *httpVersion;

@property (nonatomic, nullable) NSHTTPURLResponse *httpResponse;
@property (nonatomic, nullable) NSData *httpBody;
@property (nonatomic, nullable) NSError *httpError;
@property (nonatomic) BOOL isBrowserResponse;

- (instancetype)initWithDeviceInfo:(MSIDDeviceInfo *)deviceInfo;
- (instancetype)initWithURLResponse:(NSHTTPURLResponse *)httpResponse body:(NSData *)httpBody error:(NSError *)httpError;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
