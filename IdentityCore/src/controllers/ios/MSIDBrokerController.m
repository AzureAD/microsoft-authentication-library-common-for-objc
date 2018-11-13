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

#import "MSIDBrokerController.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDBrokerTokenRequest.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDBrokerTokenRequest.h"
#import "MSIDNotifications.h"
#import "MSIDBrokerResponseHandler.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDKeychainTokenCache.h"

@interface MSIDBrokerController()

@property (nonatomic) MSIDInteractiveRequestParameters *interactiveParameters;
@property (nonatomic, readwrite) MSIDBrokerKeyProvider *brokerKeyProvider;
@property (copy) MSIDRequestCompletionBlock requestCompletionBlock;

@end

static MSIDBrokerController *s_currentExecutingController;

@implementation MSIDBrokerController

#pragma mark - Init

- (nullable instancetype)initWithInteractiveRequestParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                         tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                        error:(NSError *_Nullable *_Nullable)error
{
    self = [super initWithRequestParameters:parameters tokenRequestProvider:tokenRequestProvider error:error];

    if (self)
    {
        _interactiveParameters = parameters;
        // TODO: verify current behavior of this keychain access group and migration scenarios
        NSString *accessGroup = parameters.keychainAccessGroup ?: MSIDKeychainTokenCache.defaultKeychainGroup;
        _brokerKeyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:accessGroup];
    }

    return self;
}

#pragma mark - MSIDInteractiveRequestControlling

- (void)acquireToken:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    if ([self.class currentBrokerController])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Broker authentication already in progress", nil, nil, nil, self.requestParameters.correlationId, nil);
        completionBlock(nil, error);
        return;
    }

    self.requestCompletionBlock = completionBlock;

    NSError *brokerError = nil;

    NSData *brokerKey = [self.brokerKeyProvider brokerKeyWithError:&brokerError];

    if (!brokerKey)
    {
        MSID_LOG_ERROR(self.requestParameters, @"Failed to retrieve broker key with error %ld, %@", (long)brokerError.code, brokerError.domain);
        MSID_LOG_ERROR_PII(self.requestParameters, @"Failed to retrieve broker key with error %@", brokerError);

        completionBlock(nil, brokerError);
        return;
    }

    NSString *base64UrlKey = [[NSString msidBase64UrlEncodedStringFromData:brokerKey] msidWWWFormURLEncode];

    if (!base64UrlKey)
    {
        MSID_LOG_ERROR(self.requestParameters, @"Unable to base64 encode broker key");

        NSError *brokerKeyError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unable to base64 encode broker key", nil, nil, nil, self.requestParameters.correlationId, nil);
        completionBlock(nil, brokerKeyError);
        return;
    }

    MSIDBrokerTokenRequest *brokerRequest = [self.tokenRequestProvider brokerTokenRequestWithParameters:self.interactiveParameters
                                                                                              brokerKey:base64UrlKey
                                                                                                  error:&brokerError];

    if (!brokerRequest)
    {
        MSID_LOG_ERROR(self.requestParameters, @"Couldn't create broker request");
        completionBlock(nil, brokerError);
        return;
    }

    NSDictionary *brokerResumeDictionary = brokerRequest.resumeDictionary;
    [[NSUserDefaults standardUserDefaults] setObject:brokerResumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self callBrokerWithRequest:brokerRequest];
}

- (void)callBrokerWithRequest:(MSIDBrokerTokenRequest *)brokerRequest
{
    [self.class setCurrentBrokerController:self];
    [self.class startTrackingAppState];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestParameters.telemetryRequestId eventName:MSID_TELEMETRY_EVENT_LAUNCH_BROKER];

    NSURL *brokerLaunchURL = brokerRequest.brokerRequestURL;

    if ([NSThread isMainThread])
    {
        [MSIDNotifications notifyWebAuthWillSwitchToBroker];
        [MSIDAppExtensionUtil sharedApplicationOpenURL:brokerLaunchURL];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MSIDNotifications notifyWebAuthWillSwitchToBroker];
            [MSIDAppExtensionUtil sharedApplicationOpenURL:brokerLaunchURL];
        });
    }
}

+ (BOOL)completeAcquireToken:(NSURL *)resultURL
       brokerResponseHandler:(MSIDBrokerResponseHandler *)responseHandler
{
    NSError *resultError = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:resultURL error:&resultError];

    if ([self.class currentBrokerController])
    {
        MSIDBrokerController *currentBrokerController = [self.class currentBrokerController];
        return [currentBrokerController completeAcquireTokenWithResult:result error:resultError];
    }

    return YES;
}

#pragma mark - Notifications

+ (void)startTrackingAppState
{
    // If the broker app itself requested a token, we don't care if it goes to background or not - the
    // user should be able to continue the flow regardless
#if !AD_BROKER
    // UIApplicationDidBecomeActive can get hit after the iOS 9 "This app wants to open this other app"
    // dialog is displayed. Because of the multitude of ways that notification can be sent we can't rely
    // merely on it to be able to accurately decide when we need to clean up. According to Apple's
    // documentation on the app lifecycle when receiving a URL we should be able to rely on openURL:
    // occuring between ApplicationWillEnterForeground and ApplicationDidBecomeActive.

    // https://developer.apple.com/library/ios/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html#//apple_ref/doc/uid/TP40007072-CH6-SW8

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appEnteredForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
#endif
}

#if !AD_BROKER

+ (void)appEnteredForeground:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];

    // Now that we know we've just been woken up from having been in the background we can start listening for
    // ApplicationDidBecomeActive without having to worry about something else causing it to get hit between
    // now and openURL:, if we're indeed getting a URL.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkTokenResponse:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
}

+ (void)checkTokenResponse:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];

    if ([self.class currentBrokerController])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerResponseNotReceived, @"application did not receive response from broker.", nil, nil, nil, nil, nil);

        MSIDBrokerController *brokerController = [self.class currentBrokerController];
        [brokerController completeAcquireTokenWithResult:nil error:error];
    }
}

#endif

+ (void)stopTrackingAppState
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

#pragma mark - Complete request

- (BOOL)completeAcquireTokenWithResult:(MSIDTokenResult *)tokenResult error:(NSError *)error
{
    // TODO: stop telemetry event

    [self.class setCurrentBrokerController:nil];
    [self.class stopTrackingAppState];

    if (self.requestCompletionBlock)
    {
        MSIDRequestCompletionBlock requestCompletion = [self.requestCompletionBlock copy];
        self.requestCompletionBlock = nil;
        requestCompletion(tokenResult, error);
        return YES;
    }

    return NO;
}

#pragma mark - Current controller

+ (void)setCurrentBrokerController:(MSIDBrokerController *)currentBrokerController
{
    @synchronized ([self class]) {
        s_currentExecutingController = currentBrokerController;
    }
}

+ (MSIDBrokerController *)currentBrokerController
{
    @synchronized ([self class]) {
        return s_currentExecutingController;
    }
}

@end
