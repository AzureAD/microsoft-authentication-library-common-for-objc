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


#import "MSIDTestLogger.h"

@implementation MSIDTestLogger

+ (void)load
{
    // We want the shared test logger to get created early so it grabs the log callback
    [MSIDTestLogger sharedLogger];
}

+ (MSIDTestLogger *)sharedLogger
{
    static dispatch_once_t onceToken;
    static MSIDTestLogger *logger;
    dispatch_once(&onceToken, ^{
        logger = [MSIDTestLogger new];
        
        [[MSIDLogger sharedLogger] setCallback:^(MSIDLogLevel level, NSString *message, BOOL containsPII) {
            [logger logLevel:level isPii:containsPII message:message];
            logger.callbackInvoked = YES;
        }];
    });
    
    return logger;
}

- (void)logLevel:(MSIDLogLevel)level isPii:(BOOL)isPii message:(NSString *)message
{
    _lastLevel = level;
    _containsPII = isPii;
    _lastMessage = message;
}

- (void)reset
{
    [self reset:MSIDLogLevelLast];
}

- (void)reset:(MSIDLogLevel)level
{
    _lastMessage = nil;
    _lastLevel = -1;
    _containsPII = NO;
    [[MSIDLogger sharedLogger] setLevel:level];
    [[MSIDLogger sharedLogger] setLogMaskingLevel:MSIDLogMaskingSettingsMaskSecretsOnly];
}

@end
