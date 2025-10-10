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

#import "MSIDRefreshToken.h"
NS_ASSUME_NONNULL_BEGIN

/*!
 @class MSIDBoundRefreshToken
 
 @brief Represents a refresh token bound to a specific device, extending MSIDRefreshToken.
 
 @discussion MSIDBoundRefreshToken is a specialized refresh token type that includes binding information to current device. This token type is used to satisfy token binding policies by associating the refresh token with the device registration's device key.
 */
@interface MSIDBoundRefreshToken : MSIDRefreshToken

/*!
 @property boundDeviceId
 
 @brief The identifier of the device to which this refresh token is bound.
 
 @discussion This property stores the device ID associated with the bound refresh token. It is meant to be a hint to check if device registration's device id matches this value.
 */
@property (nonatomic, copy) NSString *boundDeviceId;

/*!
 @brief Initializes a new instance of MSIDBoundRefreshToken with the provided refresh token, bound device identifier, and request context.
 
 @param refreshToken The bound refresh token
 @param boundDeviceId The identifier of the device to which this refresh token is bound.
 
 @return An initialized instance of MSIDBoundRefreshToken.
 */
- (instancetype)initWithRefreshToken:(MSIDRefreshToken *)refreshToken
                      boundDeviceId:(NSString *)boundDeviceId;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
