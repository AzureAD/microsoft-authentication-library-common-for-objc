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

#ifndef MSIDWorkPlaceJoinUtilProviding_h
#define MSIDWorkPlaceJoinUtilProviding_h

#import <Foundation/Foundation.h>

@class MSIDWPJMetadata;
@class MSIDWPJKeyPairWithCert;
@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/**
 Narrow seam protocol covering the WorkplaceJoin keychain class methods that
 production code routes through @c MSIDDIContainer. Tests can install a fake
 class conforming to this protocol via
 @c -[MSIDDIContainer setImplClassOverride:forProtocol:] instead of swizzling.

 Production default conformer: @c MSIDWorkPlaceJoinUtil (and its base
 @c MSIDWorkPlaceJoinUtilBase). Resolve via
 @c +[MSIDWorkPlaceJoinUtilBase resolvedProvider].
 */
@protocol MSIDWorkPlaceJoinUtilProviding <NSObject>

+ (nullable NSString *)getPrimaryEccTenantWithSharedAccessGroup:(nullable NSString *)sharedAccessGroup
                                                        context:(nullable id<MSIDRequestContext>)context
                                                          error:(NSError *_Nullable *_Nullable)error;

+ (nullable MSIDWPJMetadata *)readWPJMetadataWithSharedAccessGroup:(nullable NSString *)sharedAccessGroup
                                                  tenantIdentifier:(nullable NSString *)tenantIdentifier
                                                        domainName:(nullable NSString *)domainName
                                                           context:(nullable id<MSIDRequestContext>)context
                                                             error:(NSError *_Nullable *_Nullable)error;

+ (nullable MSIDWPJKeyPairWithCert *)getWPJKeysWithTenantId:(nullable NSString *)tenantId
                                                    context:(nullable id<MSIDRequestContext>)context;

@end

NS_ASSUME_NONNULL_END

#endif /* MSIDWorkPlaceJoinUtilProviding_h */
