//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 MSIDBRTAttemptTracker tracks BRT (Broker Refresh Token) acquisition attempts
 within a single token acquisition session. According to requirements:
 - Maximum 2 attempts per session
 - First attempt on first msauth:// or browser:// redirect
 - Second attempt only if first fails and another msauth:// or browser:// redirect occurs
 - Failures do not block the flow
 */
@interface MSIDBRTAttemptTracker : NSObject

@property (nonatomic, readonly) NSInteger attemptCount;
@property (nonatomic, readonly) BOOL canAttemptBRT;

- (instancetype)init;

/**
 Records a BRT acquisition attempt. Returns YES if the attempt was recorded,
 NO if the maximum number of attempts (2) has been reached.
 */
- (BOOL)recordAttempt;

/**
 Resets the attempt counter. This should be called at the start of a new
 token acquisition session.
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END
