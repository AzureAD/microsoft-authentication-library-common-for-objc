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

#import "MSIDBaseRequestController.h"
#import "MSIDAuthority.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDBaseRequestController()

@property (nonatomic, readwrite) MSIDRequestParameters *requestParameters;
@property (nonatomic, readwrite) id<MSIDTokenRequestProviding> tokenRequestProvider;

@end

@implementation MSIDBaseRequestController

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
                              tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                             error:(NSError *_Nullable *_Nullable)error
{
    self = [super init];

    if (self)
    {
        _requestParameters = parameters;

        NSError *parametersError = nil;

        if (![_requestParameters validateParametersWithError:&parametersError])
        {
            MSID_LOG_ERROR(self.requestParameters, @"Request parameters error %ld, %@", (long)parametersError.code, parametersError.domain);
            MSID_LOG_ERROR_PII(self.requestParameters, @"Request parameters error %@", parametersError);

            if (error)
            {
                *error = parametersError;
            }

            return nil;
        }

        _tokenRequestProvider = tokenRequestProvider;
    }

    return self;
}

- (void)resolveEndpointsWithUpn:(NSString *)upn completion:(MSIDAuthorityCompletion)completion
{
    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:self.requestParameters
                                         completionBlock:^(NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         if (error)
         {
             MSIDTelemetryAPIEvent *event = [self telemetryAPIEvent];
             [self stopTelemetryEvent:event error:error];

             completion(NO, error);
             return;
         }

         completion(YES, nil);
     }];
}

#pragma mark - Telemetry

- (MSIDTelemetryAPIEvent *)telemetryAPIEvent
{
    MSIDTelemetryAPIEvent *event = [[MSIDTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT context:self.requestParameters];

    [event setApiId:self.requestParameters.telemetryApiId];
    [event setCorrelationId:self.requestParameters.correlationId];
    [event setAuthorityType:[self.requestParameters.authority telemetryAuthorityType]];
    [event setAuthority:self.requestParameters.authority.url.absoluteString];
    [event setClientId:self.requestParameters.clientId];
    return event;
}

- (void)stopTelemetryEvent:(MSIDTelemetryAPIEvent *)event error:(NSError *)error
{
    if (error)
    {
        [event setErrorCode:error.code];
        [event setErrorDomain:error.domain];
    }

    [[MSIDTelemetry sharedInstance] stopEvent:self.requestParameters.telemetryRequestId event:event];
    [[MSIDTelemetry sharedInstance] flush:self.requestParameters.telemetryRequestId];
}

@end
