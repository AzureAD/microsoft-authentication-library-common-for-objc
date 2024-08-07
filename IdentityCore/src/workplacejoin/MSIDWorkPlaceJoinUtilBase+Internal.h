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

#ifndef MSIDWorkPlaceJoinUtilBase_Internal_h
#define MSIDWorkPlaceJoinUtilBase_Internal_h

#import <Foundation/Foundation.h>

@class MSIDWPJMetadata;

@interface MSIDWorkPlaceJoinUtilBase()

+ (nullable NSString *)getWPJStringDataForIdentifier:(nonnull NSString *)identifier
                                         accessGroup:(nullable NSString *)accessGroup
                                             context:(nullable id<MSIDRequestContext>)context
                                               error:(NSError*__nullable __autoreleasing*__nullable)error;

+ (NSString *_Nullable)getWPJStringDataFromV2ForTenantId:(NSString *_Nullable)tenantId
                                              identifier:(nonnull NSString *)identifier
                                                     key:(nullable NSString *)key
                                             accessGroup:(nullable NSString *)accessGroup
                                                 context:(id<MSIDRequestContext>_Nullable)context
                                                   error:(NSError*__nullable __autoreleasing*__nullable)error;

+ (nullable NSString *)getPrimaryEccTenantWithSharedAccessGroup:(NSString *_Nullable)sharedAccessGroup
                                                        context:(id <MSIDRequestContext> _Nullable)context
                                                          error:(NSError *_Nullable *_Nullable)error;


+ (nullable MSIDWPJMetadata *)readWPJMetadataWithSharedAccessGroup:(NSString *_Nullable)sharedAccessGroup
                                                  tenantIdentifier:(NSString *_Nullable)tenantIdentifier
                                                        domainName:(NSString *_Nullable)domainName
                                                           context:(id <MSIDRequestContext> _Nullable)context
                                                             error:(NSError *_Nullable *_Nullable)error;

@end

#endif /* MSIDWorkPlaceJoinUtilBase_Internal_h */
