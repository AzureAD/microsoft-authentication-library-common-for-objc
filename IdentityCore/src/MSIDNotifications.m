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

#import "MSIDNotifications.h"

#define MSID_NOTIFICATION_READ_PROPERTY(KEY, GETTER) \
+ (NSString *)GETTER { return KEY; }

#define MSID_NOTIFICATION_WRITE_PROPERTY(KEY, SETTER) \
+ (void)SETTER:(NSString *)value { KEY = value; }

#define MSID_NOTIFICATION_RW(KEY, GETTER, SETTER) \
MSID_NOTIFICATION_READ_PROPERTY(KEY, GETTER) \
MSID_NOTIFICATION_WRITE_PROPERTY(KEY, SETTER)

static NSString *s_webAuthDidStartLoadNotification;
static NSString *s_webAuthDidFinishLoadNotification;
static NSString *s_webAuthDidFailNotification;
static NSString *s_webAuthDidCompleteNotification;
static NSString *s_webAuthWillSwitchToBrokerApp;
static NSString *s_webAuthDidReceieveResponseFromBroker;

@implementation MSIDNotifications

MSID_NOTIFICATION_RW(s_webAuthDidStartLoadNotification, webAuthDidStartLoadNotification, setWebAuthDidStartLoadNotification);
MSID_NOTIFICATION_RW(s_webAuthDidFinishLoadNotification, webAuthDidFinishLoadNotification, setWebAuthDidFinishLoadNotification);
MSID_NOTIFICATION_RW(s_webAuthDidFailNotification, webAuthDidFailNotification, setWebAuthDidFailNotification);
MSID_NOTIFICATION_RW(s_webAuthDidCompleteNotification, webAuthDidCompleteNotification, setWebAuthDidCompleteNotification);
MSID_NOTIFICATION_RW(s_webAuthWillSwitchToBrokerApp, webAuthWillSwitchToBrokerApp, setWebAuthWillSwitchToBrokerApp);
MSID_NOTIFICATION_RW(s_webAuthDidReceieveResponseFromBroker, webAuthDidReceieveResponseFromBroker, setWebAuthDidReceieveResponseFromBroker);

@end
