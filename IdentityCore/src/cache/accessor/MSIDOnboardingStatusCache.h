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

@class MSIDOnboardingStatus;
@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/**
 Cache accessor for reading and writing MSIDOnboardingStatus items to the keychain.
 This class uses MSIDKeychainTokenCache.defaultKeychainGroup as its data source.
 */
@interface MSIDOnboardingStatusCache : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 Shared instance of MSIDOnboardingStatusCache using the default keychain group.
 */
@property (class, readonly, nonnull) MSIDOnboardingStatusCache *sharedInstance;

/**
 Sets the onboarding status.
 
 @param status The MSIDOnboardingStatus to set.
 @return YES if the operation succeeds, NO otherwise.
 */
- (BOOL)setWithStatus:(MSIDOnboardingStatus *)status;

/**
 Gets the current onboarding status.
 
 @return The MSIDOnboardingStatus representing the current status. If no status is stored, a default status object is returned.
 */
- (MSIDOnboardingStatus *)getOnboardingStatus;

/**
 Clears the onboarding status for a specific bundle identifier.
 
 @param bundleId The bundle identifier to clear the status for.
 @return YES if the operation succeeds, NO otherwise.
 */
- (BOOL)clear:(NSString *)bundleId;

@end

NS_ASSUME_NONNULL_END
