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


#import "MSIDXpcConfiguration.h"

static NSString *machServiceName = @"UBF8T346G9.com.microsoft.entrabroker.EntraIdentityBrokerXPC.Mach";
static NSString *machServiceMacBrokerName = @"UBF8T346G9.com.microsoft.entrabrokermacbroker.EntraIdentityBrokerXPC.Mach";
static NSString *brokerDispatcher = @"com.microsoft.entrabroker.BrokerApp";
static NSString *brokerMacBrokerDispatcher = @"com.microsoft.entrabrokermacbroker.BrokerApp";

@implementation MSIDXpcConfiguration

- (instancetype)initWithXpcProviderType:(MSIDSsoProviderType)xpcProviderType
{
    self = [super init];
    if (self)
    {
        self.xpcProviderType = xpcProviderType;
        switch (xpcProviderType) {
            case MSIDCompanyPortalSsoProvider:
                self.xpcHostAppName = @"Company Portal app";
                self.xpcMachServiceName = machServiceName;
                self.xpcBrokerDispatchServiceBundleId = brokerDispatcher;
                self.xpcBrokerInstanceServiceBundleId = brokerInstance;
                break;
            case MSIDMacBrokerSsoProvider:
                self.xpcHostAppName = @"Mac Broker app";
                self.xpcMachServiceName = machServiceMacBrokerName;
                self.xpcBrokerDispatchServiceBundleId = brokerMacBrokerDispatcher;
                self.xpcBrokerInstanceServiceBundleId = brokerMacBrokerInstance;
                break;
            default:
                return nil;
        }
    }
    
    return self;
}

@end
