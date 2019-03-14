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

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAutomationActionConstants : NSObject

extern NSString *const MSID_AUTO_CLEAR_CACHE_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_CLEAR_COOKIES_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_OPEN_URL_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_ACQUIRE_TOKEN_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_ACQUIRE_TOKEN_SILENT_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_EXPIRE_AT_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_INVALIDATE_RT_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_REMOVE_ACCOUNT_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_REMOVE_ACCOUNT_FROM_BROKER_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_REMOVE_ACCOUNT_FROM_DEVICE_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_READ_ACCOUNTS_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_ACQUIRE_TOKEN_WITH_RT_IDENTIFIER;
extern NSString *const MSID_AUTO_EMPTY_STRESS_TEST_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_NON_EMPTY_STRESS_TEST_ACTION_IDENTIFIER;
extern NSString *const MSID_AUTO_INTERACTIVE_STRESS_TEST_ACTION_IDENTIFIER;

@end

NS_ASSUME_NONNULL_END
