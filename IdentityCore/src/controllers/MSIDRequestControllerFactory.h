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
#import "MSIDRequestControlling.h"
#import "MSIDTokenRequestProviding.h"

@class MSIDInteractiveTokenRequestParameters;
@class MSIDRequestParameters;
@class MSIDSignoutController;
@class MSIDOauth2Factory;
@class MSIDInteractiveRequestParameters;

typedef NS_ENUM(NSInteger, MSIDSilentControllerLocalRtUsageType)
{
    MSIDSilentControllerForceSkippingLocalRt = 0,
    MSIDSilentControllerForceUsingLocalRt = 1,
    MSIDSilentControllerUndefinedLocalRtUsage = 2
};

@interface MSIDRequestControllerFactory : NSObject

+ (nullable id<MSIDRequestControlling>)silentControllerForParameters:(nonnull MSIDRequestParameters *)parameters
                                                        forceRefresh:(BOOL)forceRefresh
                                                         skipLocalRt:(MSIDSilentControllerLocalRtUsageType)skipLocalRt
                                                tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

+ (nullable id<MSIDRequestControlling>)interactiveControllerForParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                                     tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error;

+ (nullable MSIDSignoutController *)signoutControllerForParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                                          shouldSignoutFromBrowser:(BOOL)shouldSignoutFromBrowser
                                                 shouldWipeAccount:(BOOL)shouldWipeAccount
                                     shouldWipeCacheForAllAccounts:(BOOL)shouldWipeCacheForAllAccounts
                                                             error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end
