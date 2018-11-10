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

#import "MSIDBrokerTokenRequest.h"
#import "MSIDBrokerPayload.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDBrokerTokenRequest()

@property (nonatomic, readwrite) MSIDRequestCompletionBlock requestCompletionBlock;
@property (nonatomic, readwrite) MSIDInteractiveRequestParameters *requestParameters;
@property (nonatomic, readwrite) MSIDOauth2Factory *oauthFactory;
@property (nonatomic, readwrite) MSIDTokenResponseValidator *tokenResponseValidator;

@end

@implementation MSIDBrokerTokenRequest

#pragma mark - Init

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
{
    self = [super init];

    if (self)
    {
        _requestParameters = parameters;
        _oauthFactory = oauthFactory;
        _tokenResponseValidator = tokenResponseValidator;
    }

    return self;
}

#pragma mark - Acquire token

- (void)acquireToken:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    NSError *payloadError = nil;
    MSIDBrokerPayload *brokerPayload = [self brokerPayloadWithError:&payloadError];

    if (!brokerPayload)
    {
        MSID_LOG_ERROR(self.requestParameters, @"Couldn't create broker payload");
        completionBlock(nil, payloadError);
        return;
    }

    NSURL *brokerLaunchURL = brokerPayload.brokerRequestURL;

    // TODO: telemetry should be in controller?
    [[MSIDTelemetry sharedInstance] startEvent:self.requestParameters.telemetryRequestId eventName:MSID_TELEMETRY_EVENT_LAUNCH_BROKER];

    [self invokeBrokerWithURL:brokerLaunchURL completionBlock:completionBlock];

    // Save request to pasteboard
    // Save completion handler
    // Compose URL
    // Open URL
}

#pragma mark - Helpers

- (void)invokeBrokerWithURL:(NSURL *)brokerURL
            completionBlock:(MSIDRequestCompletionBlock)completionBlock
{
    self.requestCompletionBlock = completionBlock;

    
}

/*
+ (void)invokeBroker:(NSURL *)brokerURL
   completionHandler:(ADAuthenticationCallback)completion
{
    [[ADBrokerNotificationManager sharedInstance] enableNotifications:completion];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:ADWebAuthWillSwitchToBrokerApp object:nil];

        [ADAppExtensionUtil sharedApplicationOpenURL:brokerURL];
    });
}*/

#pragma mark - Abstract

- (MSIDBrokerPayload *)brokerPayloadWithError:(NSError **)error
{
    NSAssert(NO, @"Abstract method. implement in subclasses!");
    return nil;
}

@end
