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

NS_ASSUME_NONNULL_BEGIN

@interface MSIDGCDStarvationHandler : NSObject

+ (instancetype)sharedHandler;

/// Detects if GCD thread pool is starved
/// @param timeout How long to wait for a simple GCD task (e.g., 10ms)
/// @return YES if thread starvation detected
- (BOOL)isGCDThreadPoolStarvedWithTimeout:(NSTimeInterval)timeout;

/// Execute block on GCD if available, otherwise fallback to custom thread
/// @param block Block to execute
/// @param fallbackToCustomThread Whether to use custom thread if GCD is starved
- (void)executeBlock:(dispatch_block_t)block fallbackToCustomThread:(BOOL)fallbackToCustomThread;

@end

NS_ASSUME_NONNULL_END
