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


#import "MSIDDarwinNotificationListener.h"
#import "MSIDConstants.h"

static NSString *const kDarwinNotificationReceivedKey = @"DarwinNotificationReceived";

static void sharedModeAccountChangedCallback(__unused CFNotificationCenterRef center,
                                             __unused void * observer,
                                             CFStringRef name,
                                             __unused void const * object,
                                             __unused CFDictionaryRef userInfo)
{
    if ([(__bridge NSString *)name isEqualToString: MSID_SHARED_MODE_CURRENT_ACCOUNT_CHANGED_NOTIFICATION_KEY])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,nil, @"Received shared device mode account change Darwin notification broadcast");

        [[NSNotificationCenter defaultCenter] postNotificationName:kDarwinNotificationReceivedKey object:nil];
    }
}

@implementation MSIDDarwinNotificationListener

- (instancetype)initWithCallback:(MSIDDarwinNotificationCallback)passedInCallback
{
    if (!passedInCallback)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"No callback passed to MSIDDarwinNotificationListener");
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _passedInCallback = passedInCallback;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(receivedGlobalSignoutDarwinNotification:)
                                                     name:kDarwinNotificationReceivedKey
                                                   object:nil];
    }
    return self;
}

- (void)createSharedDeviceAccountChangeListener
{
    if (!self.passedInCallback)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"No callback available when creating Darwin notification listener");
    }
    
    //Listens for Darwin notifcations coming from broker in the FLW global signout scenario
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, nil, sharedModeAccountChangedCallback, (CFStringRef)MSID_SHARED_MODE_CURRENT_ACCOUNT_CHANGED_NOTIFICATION_KEY,
                                    nil, CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)receivedGlobalSignoutDarwinNotification:(NSNotification *)notification
{
    if (self.passedInCallback)
    {
        self.passedInCallback(nil);
    }
}

@end
