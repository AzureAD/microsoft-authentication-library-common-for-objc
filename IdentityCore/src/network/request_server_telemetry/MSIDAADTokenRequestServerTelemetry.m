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

#import "MSIDAADTokenRequestServerTelemetry.h"
#import "MSIDCurrentRequestTelemetry.h"
#import "MSIDLastRequestTelemetry.h"
#import "MSIDResponseErrorProviding.h"

@interface MSIDAADTokenRequestServerTelemetry()

@property (nonatomic) MSIDLastRequestTelemetry *lastRequestTelemetry;

@end

@implementation MSIDAADTokenRequestServerTelemetry

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _lastRequestTelemetry = [MSIDLastRequestTelemetry sharedInstance];
    }
    return self;
}
// TODO: unused param
- (void)handleHttpResponse:(NSHTTPURLResponse *)httpResponse
                      data:(NSData *)data
                forRequest:(__unused id<MSIDHttpRequestProtocol>)request
                   context:(id<MSIDRequestContext>)context
{
    NSError *error;
    NSString *errorString = [self.responseErrorProvider errorForResponse:httpResponse
                                                                    data:data
                                                                 context:context
                                                                   error:&error];
    
    [self.lastRequestTelemetry updateWithApiId:self.apiId
                                   errorString:errorString
                                       context:context];
}

- (void)setTelemetryToRequest:(id<MSIDHttpRequestProtocol>)request
{
    NSParameterAssert(request.urlRequest);
    
    MSIDCurrentRequestTelemetry *currentRequestTelemetry = [MSIDCurrentRequestTelemetry new];
    currentRequestTelemetry.schemaVersion = 2;
    currentRequestTelemetry.forceRefresh = self.forceRefresh;
    currentRequestTelemetry.apiId = self.apiId;
    
    NSString *currentRequestTelemetryString = [currentRequestTelemetry telemetryString];
    
    NSString *lastRequestTelemetryString = [self.lastRequestTelemetry telemetryString];
    
    NSMutableURLRequest *mutableUrlRequest = [request.urlRequest mutableCopy];
    [mutableUrlRequest setValue:currentRequestTelemetryString forHTTPHeaderField:@"x-client-current-telemetry"];
    [mutableUrlRequest setValue:lastRequestTelemetryString forHTTPHeaderField:@"x-client-last-telemetry"];
    
    request.urlRequest = mutableUrlRequest;
}

@end
