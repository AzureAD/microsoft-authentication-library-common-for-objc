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

#import <Foundation/Foundation.h>
#import "MSIDHttpRequestProtocol.h"

@protocol MSIDRequestSerialization;
@protocol MSIDResponseSerialization;
@protocol MSIDRequestContext;
@protocol MSIDHttpRequestTelemetryProtocol;
@protocol MSIDHttpRequestErrorHandlerProtocol;

/**
 Important: You need to call `finishAndInvalidate` method in `completionBlock` of `sendWithBlock:`.
 If you don’t call, the app leaks memory until it exits.
 */
@interface MSIDHttpRequest : NSObject <MSIDHttpRequestProtocol>
{
    @protected NSDictionary<NSString *, NSString *> *_parameters;
    @protected NSURLRequest *_urlRequest;
    @protected id<MSIDRequestSerialization> _requestSerializer;
    @protected id<MSIDResponseSerialization> _responseSerializer;
    @protected id<MSIDHttpRequestTelemetryProtocol> _telemetry;
    @protected id<MSIDHttpRequestErrorHandlerProtocol> _errorHandler;
}

@property (nonatomic, nullable) NSDictionary<NSString *, NSString *> *parameters;

@property (nonatomic, nullable) NSURLRequest *urlRequest;

@property (nonatomic, nonnull) id<MSIDRequestSerialization> requestSerializer;

@property (nonatomic, nonnull) id<MSIDResponseSerialization> responseSerializer;

@property (nonatomic, nullable) id<MSIDHttpRequestTelemetryProtocol> telemetry;

@property (nonatomic, nullable) id<MSIDHttpRequestErrorHandlerProtocol> errorHandler;

@property (nonatomic, nullable) id<MSIDRequestContext> context;

@end
