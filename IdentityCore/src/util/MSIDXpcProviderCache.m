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


#import "MSIDXpcProviderCache.h"
#import "NSString+MSIDExtensions.h"
#import "NSDate+MSIDExtensions.h"
#import "MSIDDeviceInfo.h"
#import "MSIDXpcConfiguration.h"

NSString *const MSID_XPC_CACHE_QUEUE_NAME = @"com.microsoft.msidxpcprovidercache";
NSString *const MSID_XPC_PROVIDER_TYPE_KEY = @"xpc_provider_type";
NSString *const MSID_XPC_LAST_UPDATE_TIME = @"last_update_time";
NSString *const MSID_XPC_LAST_UPDATE_TIME_DESCRIPTION = @"last_update_time_description";
NSString *const MSID_XPC_STATUS = @"xpc_status";
NSTimeInterval const MSID_XPC_STATUS_EXPIRATION_TIME = 14400.0;

@interface MSIDXpcProviderCache ()

@property (nonatomic) NSMutableDictionary *container;
@property (nonatomic) dispatch_queue_t synchronizationQueue;
@property (nonatomic) BOOL isMacBrokerXpcProviderInstalled;
@property (nonatomic) BOOL isCompanyPortalXpcProviderInstalled;
@property (nonatomic) NSUserDefaults *userDefaults;

@end

@implementation MSIDXpcProviderCache

+ (instancetype)sharedInstance
{
    static MSIDXpcProviderCache *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self.class alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        NSString *queueName = [NSString stringWithFormat:@"%@-%@", MSID_XPC_CACHE_QUEUE_NAME, [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
        _userDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    return self;
}

- (MSIDSsoProviderType)cachedXpcProviderType
{
    __block NSInteger result;
    dispatch_sync(self.synchronizationQueue, ^{
        result = [self.userDefaults integerForKey:MSID_XPC_PROVIDER_TYPE_KEY];
    });
    
    return result;
}

- (void)setCachedXpcProviderType:(MSIDSsoProviderType)cachedXpcProvider
{
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        [self.userDefaults setInteger:cachedXpcProvider forKey:MSID_XPC_PROVIDER_TYPE_KEY];
        self.xpcConfiguration = [[MSIDXpcConfiguration alloc] initWithXpcProviderType:cachedXpcProvider];
    });
}

- (BOOL)isXpcProviderInstalledOnDevice
{
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        self.isMacBrokerXpcProviderInstalled = [self isXpcProviderExist:macBrokerAppXpcInstance];
        self.isCompanyPortalXpcProviderInstalled = [self isXpcProviderExist:companyPortalXpcInstance];
    });
    
    return self.isMacBrokerXpcProviderInstalled || self.isCompanyPortalXpcProviderInstalled;
}

- (BOOL)isXpcProviderExist
{
    if (!self.xpcConfiguration)
    {
        // if there is no xpcConfiguration here
        // we will use manual logic and try best to use Xpc component from MacBrokerApp first
        // If fails, then try to use from CompanyPortalApp
        
        if (self.isMacBrokerXpcProviderInstalled)
        {
            self.cachedXpcProviderType = MSIDMacBrokerSsoProvider;
            return YES;
        }
        else if (self.isCompanyPortalXpcProviderInstalled)
        {
            self.cachedXpcProviderType = MSIDCompanyPortalSsoProvider;
            return YES;
        }
        
        return NO;
    }
    
    // Otherwise when xpcConfiguration mismatched with the existence of the Xpc provider (CP or MacBro App), fallback to the existed one on device
    if (![self isXpcProviderExist:self.xpcConfiguration.xpcBrokerInstanceServiceBundleId])
    {
        // When cached Xpc configuration is available, but out of date and the Xpc component has been removed from device
        // Let's switch to the other Xpc configuration.
        if (self.isMacBrokerXpcProviderInstalled && self.xpcConfiguration.xpcProviderType == MSIDCompanyPortalSsoProvider)
        {
            // When BrokerApp Xpc is installed and cannot find CompanyPortal Xpc, we will switch to use BrokerApp Xpc
            self.cachedXpcProviderType = MSIDMacBrokerSsoProvider;
        }
        else if (self.isCompanyPortalXpcProviderInstalled && self.xpcConfiguration.xpcProviderType == MSIDMacBrokerSsoProvider)
        {
            // When CompanyPortal Xpc is installed and cannot find BrokerApp Xpc, we will switch to use CompanyPortal Xpc
            self.cachedXpcProviderType = MSIDCompanyPortalSsoProvider;
        }
        else
        {
            // No backup Xpc provider available, return NO
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)isXpcProviderExist:(NSString *)xpcIdentifier
{
    NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:xpcIdentifier];
    return appURL != nil && [[NSFileManager defaultManager] fileExistsAtPath:[appURL path]];
}

- (BOOL)shouldReturnCachedXpcStatus
{
    __block BOOL result = YES;
    dispatch_sync(self.synchronizationQueue, ^{
        
        if (!self.xpcConfiguration)
        {
            result = NO;
        }
        else
        {
            NSDictionary *xpcInfo = [[NSUserDefaults standardUserDefaults] dictionaryForKey:self.xpcConfiguration.xpcMachServiceName];
            if (!xpcInfo)
            {
                result = NO;
            }
            else
            {
                NSDate *lastUpdatedTime = [NSDate msidDateFromTimeStamp:xpcInfo[MSID_XPC_LAST_UPDATE_TIME]];
                NSTimeInterval timeDifference = [[NSDate date] timeIntervalSinceDate:lastUpdatedTime];

                // cached Broker Xpc status expired after 4 hours
                if (!lastUpdatedTime || timeDifference > MSID_XPC_STATUS_EXPIRATION_TIME)
                {
                    result = NO;
                }
            }
        }
    });
    
    return result;
}

- (BOOL)cachedXpcStatus
{
    __block BOOL result = NO;
    dispatch_sync(self.synchronizationQueue, ^{
        if (!self.xpcConfiguration)
        {
            result = NO;
        }
        else
        {
            NSDictionary *xpcInfo = [[NSUserDefaults standardUserDefaults] dictionaryForKey:self.xpcConfiguration.xpcMachServiceName];
            if ([xpcInfo[MSID_XPC_STATUS] respondsToSelector:@selector(boolValue)])
            {
                result = [xpcInfo[MSID_XPC_STATUS] boolValue];
            }
        }
    });
    
    return result;
}

- (void)setCachedXpcStatus:(BOOL)cachedXpcStatus
{
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        if (!self.xpcConfiguration)
        {
            return;
        }
        
        NSDate *currentTime = [NSDate date];
        NSDictionary *xpcInfo = @{MSID_XPC_LAST_UPDATE_TIME:[currentTime msidDateToTimestamp], MSID_XPC_LAST_UPDATE_TIME_DESCRIPTION:[currentTime msidToString], MSID_XPC_STATUS:@(cachedXpcStatus)};
        [self.userDefaults setObject:xpcInfo forKey:self.xpcConfiguration.xpcMachServiceName];
    });
}

- (MSIDXpcConfiguration *)xpcConfiguration
{
    @synchronized (self) {
        if (!_xpcConfiguration)
        {
            _xpcConfiguration = [[MSIDXpcConfiguration alloc] initWithXpcProviderType:self.cachedXpcProviderType];
        }
        
        return _xpcConfiguration;
    }
}

@end
