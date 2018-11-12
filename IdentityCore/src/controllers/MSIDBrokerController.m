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

@interface MSIDBrokerController()

@property (nonatomic) MSIDInteractiveRequestParameters *interactiveParameters;
@property MSIDBrokerTokenRequest *currentRequest;
@property (nonatomic, copy) MSIDRequestCompletionBlock requestCompletionBlock;

@end

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
    }

    return self;
}

#pragma mark - MSIDInteractiveRequestControlling

- (void)acquireToken:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    s_currentController = self;

    if (self.currentRequest)
    {
        self.currentRequest = nil;

        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Broker authentication already in progress", nil, nil, nil, self.requestParameters.correlationId, nil);
        completionBlock(nil, error);
        return;
    }

    self.currentRequest = [self.tokenRequestProvider brokerTokenRequestWithParameters:self.interactiveParameters];
    self.requestCompletionBlock = completionBlock;

    [self startTrackingAppState];

    NSError *error = nil;

    [[MSIDTelemetry sharedInstance] startEvent:self.requestParameters.telemetryRequestId eventName:MSID_TELEMETRY_EVENT_LAUNCH_BROKER];

    BOOL result = [self.currentRequest launchBrokerWithError:&error];

    if (!result)
    {
        // TODO: stop telemetry event

        [self stopTrackingAppState];
        self.currentRequest = nil;

        completionBlock(nil, error);
        return;
    }
}

+ (BOOL)completeAcquireToken:(NSURL *)resultURL
       brokerResponseHandler:(MSIDBrokerResponseHandler *)responseHandler
                       error:(NSError **)error
{
    // TODO: implement me
    return NO;
}

- (BOOL)completeAcquireToken:(NSURL *)resultURL error:(NSError **)error
{
    // TODO: replace me with completionBlock checking
    if (self.currentRequest)
    {
        //BOOL result = [self.currentRequest completeBrokerRequestWithResponse:resultURL error:error];

        // TODO: stop broker telemetry event

        // Cleanup request
        self.currentRequest = nil;
        [self stopTrackingAppState];

        return NO;
    }

    return NO;
}

#pragma mark - Notifications

- (void)startTrackingAppState
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

- (void)appEnteredForeground:(NSNotification *)notification
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

- (void)checkTokenResponse:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];

    if (self.currentRequest)
    {
        self.currentRequest = nil;

        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerResponseNotReceived, @"application did not receive response from broker.", nil, nil, nil, self.requestParameters.correlationId, nil);

        if (self.requestCompletionBlock)
        {
            self.requestCompletionBlock(nil, error);
            return;
        }
    }
}

#endif

- (void)stopTrackingAppState
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

@end
