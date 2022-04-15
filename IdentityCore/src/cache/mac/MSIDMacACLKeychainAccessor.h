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
#import "MSIDRequestContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDMacACLKeychainAccessor : NSObject

@property (class, nullable) dispatch_queue_t synchronizationQueue;
@property (readonly, nonnull) id accessControlForSharedItems;
@property (readonly, nonnull) id accessControlForNonSharedItems;

#pragma mark - Init

- (nullable instancetype)initWithTrustedApplications:(nullable NSArray *)trustedApplications
                                         accessLabel:(nonnull NSString *)accessLabel
                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

#pragma mark - Operations

- (BOOL)saveData:(nonnull NSData *)data
      attributes:(nonnull NSDictionary *)attributes
         context:(nullable id<MSIDRequestContext>)context
           error:(NSError * _Nullable * _Nullable)error;


- (BOOL)removeItemWithAttributes:(nonnull NSDictionary *)attributes
                         context:(nullable id<MSIDRequestContext>)context
                           error:(NSError * _Nullable * _Nullable)error;


- (nullable NSData *)getDataWithAttributes:(nonnull NSDictionary *)attributes
                                   context:(nullable id<MSIDRequestContext>)context
                                     error:(NSError * _Nullable * _Nullable)error;

- (BOOL)clearWithAttributes:(nonnull NSDictionary *)attributes
                    context:(nullable id<MSIDRequestContext>)context
                      error:(NSError * _Nullable * _Nullable)error;

#pragma mark - Util

- (BOOL)createError:(nonnull NSString *)message
             domain:(nonnull NSErrorDomain)domain
          errorCode:(NSInteger)code
              error:(NSError *_Nullable *_Nullable)error
            context:(nullable id<MSIDRequestContext>)context;

@end

NS_ASSUME_NONNULL_END
