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

#import "MSIDRequestControllerFactory.h"
#import "MSIDSilentRequestParameters.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAutoRequestController.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDBrokerController.h"
#import "MSIDSilentController.h"

@implementation MSIDRequestControllerFactory

+ (nullable id<MSIDRequestControlling>)silentControllerForParameters:(nonnull MSIDSilentRequestParameters *)parameters
{
    return [[MSIDSilentController alloc] initWithRequestParameters:parameters];
}

+ (nullable id<MSIDInteractiveRequestControlling>)interactiveControllerForParameters:(nonnull MSIDInteractiveRequestParameters *)parameters error:(NSError *_Nullable *_Nullable)error
{
    if (parameters.requestType == MSIDInteractiveRequestBrokeredType
        && [self brokerAllowedForParameters:parameters])
    {
        if (![self validateBrokerConfiguration:parameters error:error])
        {
            // TODO: log error
            return nil;
        }

        return [[MSIDBrokerController alloc] initWithRequestParameters:parameters];
    }

    // Else check for prompt auto and return interactive otherwise
    if (parameters.uiBehaviorType == MSIDUIBehaviorPromptAutoType)
    {
        return [[MSIDAutoRequestController alloc] initWithRequestParameters:parameters];
    }

    return [[MSIDLocalInteractiveController alloc] initWithRequestParameters:parameters];
}

+ (BOOL)brokerAllowedForParameters:(MSIDInteractiveRequestParameters *)parameters
{
    // TODO: implement me
    // Check that correct version of broker has been installed and broker is allowed
    return NO;
}

+ (BOOL)validateBrokerConfiguration:(MSIDInteractiveRequestParameters *)parameters error:(NSError **)error
{
    // TODO: implement me
    return NO;
}

@end
