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

#import <Foundation/Foundation.h>
#import "MSIDWorkPlaceJoinUtilProviding.h"

@class MSIDWPJKeyPairWithCert;

NS_ASSUME_NONNULL_BEGIN

typedef MSIDWPJMetadata * _Nullable (^MSIDFakeWPJMetadataBlock)(NSError *_Nullable *_Nullable error);

/*!
 Test fake implementing MSIDWorkPlaceJoinUtilProviding so unit tests can
 substitute the WorkplaceJoin keychain seam via @c MSIDDIContainer instead of
 swizzling @c MSIDWorkPlaceJoinUtil class methods.

 Usage:
   MSIDFakeWPJUtilProvider.primaryEccTenantId = @"tenant";
   MSIDFakeWPJUtilProvider.metadataBlock = ^MSIDWPJMetadata *(NSError **e) { ... };
   MSIDFakeWPJUtilProvider.wpjKeys = nil;
   [[MSIDDIContainer sharedInstance]
       setImplClassOverride:[MSIDFakeWPJUtilProvider class]
                forProtocol:\@protocol(MSIDWorkPlaceJoinUtilProviding)];

 Call @c +reset in @c -tearDown (along with @c -resetAllOverrides on the
 container) to clear state between tests.
 */
@interface MSIDFakeWPJUtilProvider : NSObject <MSIDWorkPlaceJoinUtilProviding>

@property (class, nonatomic, copy, nullable) NSString *primaryEccTenantId;
@property (class, nonatomic, copy, nullable) MSIDFakeWPJMetadataBlock metadataBlock;
@property (class, nonatomic, strong, nullable) MSIDWPJKeyPairWithCert *wpjKeys;

+ (void)reset;

@end

NS_ASSUME_NONNULL_END
