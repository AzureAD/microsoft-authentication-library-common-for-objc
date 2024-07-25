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
#import "MSIDSSOExtensionRequestDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ADBChildBrokerProtocol <NSObject>

- (void)handleXpcWithRequestParams:(NSDictionary *)passedInParams
                                   parentViewFrame:(NSRect)frame
                                   completionBlock:(void (^)(NSDictionary<NSString *,id> * _Nonnull, NSDate * _Nonnull, NSString * _Nonnull, NSError * _Nullable))blockName;

@end

@protocol ADBParentXPCServiceProtocol <NSObject>

- (void)connectToBrokerWithRequestInfo:(NSDictionary *)requestInfo
                  connectionCompletion:(void (^)(NSXPCListenerEndpoint *listenerEndpoint, NSDictionary *params, NSError *error))completion;

- (void)getBrokerInstanceEndpointWithRequestInfo:(NSDictionary <NSString *, id> * _Nullable)requestInfo
                            reply:(void (^)(NSXPCListenerEndpoint  * _Nullable listenerEndpoint, NSDictionary * _Nullable params, NSError * _Nullable error))reply;

@end

typedef void (^NSXPCListenerEndpointTearDownBlock)(id<ADBChildBrokerProtocol> _Nonnull xpcService);

@interface MSIDXPCServiceEndpointAccessory : NSObject


// For interactive
// Note: completion thread is not gurantee, please submit to the correct thread as needed
- (void)handleRequestParam:(NSDictionary *)requestParam
           parentViewFrame:(NSRect)frame
                 brokerKey:brokerKey
 assertKindOfResponseClass:(Class)aClass
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock;

// For silent
- (void)handleRequestParam:(NSDictionary *)requestParam
                 brokerKey:brokerKey
 assertKindOfResponseClass:(Class)aClass
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock;

@end

NS_ASSUME_NONNULL_END
