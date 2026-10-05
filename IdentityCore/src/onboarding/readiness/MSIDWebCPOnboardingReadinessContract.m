//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#import "MSIDWebCPOnboardingReadinessContract.h"
#import "MSIDOnboardingReadiness.h"

const NSInteger MSIDWebCPOnboardingReadinessContractVersion = 1;

static NSString * const MSIDWebCPOnboardingReadinessActionName = @"get_onboarding_readiness";
static NSString * const MSIDWebCPOnboardingReadinessActionComponent = @"native";

@implementation MSIDWebCPOnboardingReadinessContract

+ (instancetype)sharedInstance
{
    static MSIDWebCPOnboardingReadinessContract *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [MSIDWebCPOnboardingReadinessContract new];
    });
    return instance;
}

- (NSString *)actionName
{
    return MSIDWebCPOnboardingReadinessActionName;
}

- (NSString *)actionComponent
{
    return MSIDWebCPOnboardingReadinessActionComponent;
}

- (MSIDWebCPOnboardingReadinessRequestValidation)validateRequest:(nullable id)request
{
    if (![request isKindOfClass:[NSDictionary class]])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"WebCP readiness request is not a dictionary.");
        return MSIDWebCPOnboardingReadinessRequestValidationMalformed;
    }
    NSDictionary *envelope = request;
    id action = envelope[@"action_name"];
    id component = envelope[@"action_component"];
    if (![action isKindOfClass:[NSString class]] || ![component isKindOfClass:[NSString class]])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"WebCP readiness request action or component is malformed.");
        return MSIDWebCPOnboardingReadinessRequestValidationMalformed;
    }
    if (![action isEqualToString:[self actionName]] || ![component isEqualToString:[self actionComponent]])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"WebCP readiness action or component not supported.");
        return MSIDWebCPOnboardingReadinessRequestValidationNotSupported;
    }
    NSSet *allowedKeys = [NSSet setWithArray:@[@"correlationID", @"action_name", @"action_component", @"params"]];
    if (![[NSSet setWithArray:envelope.allKeys] isSubsetOfSet:allowedKeys])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"WebCP readiness request has unexpected envelope keys.");
        return MSIDWebCPOnboardingReadinessRequestValidationMalformed;
    }

    id parameters = envelope[@"params"];
    if (![parameters isKindOfClass:[NSDictionary class]] || [parameters count] != 1)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"WebCP readiness request parameters are malformed.");
        return MSIDWebCPOnboardingReadinessRequestValidationMalformed;
    }
    NSDictionary *parameterDictionary = parameters;
    id version = parameterDictionary[@"contractVersion"];
    if (![version isKindOfClass:[NSNumber class]]
        || CFGetTypeID((__bridge CFTypeRef)version) == CFBooleanGetTypeID()
        || [version doubleValue] != [version integerValue])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"WebCP readiness contract version is malformed.");
        return MSIDWebCPOnboardingReadinessRequestValidationMalformed;
    }
    if ([version integerValue] != MSIDWebCPOnboardingReadinessContractVersion)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"WebCP readiness contract version is not supported.");
        return MSIDWebCPOnboardingReadinessRequestValidationNotSupported;
    }
    return MSIDWebCPOnboardingReadinessRequestValidationValid;
}

- (NSString *)correlationIDForRequest:(nullable id)request generated:(BOOL *)generated
{
    id value = [request isKindOfClass:[NSDictionary class]] ? request[@"correlationID"] : nil;
    NSUUID *uuid = [value isKindOfClass:[NSString class]] ? [[NSUUID alloc] initWithUUIDString:value] : nil;
    BOOL valid = uuid && [uuid.UUIDString caseInsensitiveCompare:value] == NSOrderedSame;
    if (generated)
    {
        *generated = !valid;
    }
    if (!valid)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"WebCP readiness correlation ID was generated.");
    }
    return valid ? value : [NSUUID UUID].UUIDString;
}

- (NSDictionary<NSString *, id> *)responseWithStatus:(MSIDWebCPOnboardingReadinessResponseStatus)status
                                        correlationID:(NSString *)correlationID
                                            readiness:(MSIDOnboardingReadiness *)readiness
{
    NSString *statusString = @"Failed";
    NSDictionary *result = @{};
    if (status == MSIDWebCPOnboardingReadinessResponseStatusSuccess)
    {
        NSDictionary *readinessResult = readiness.jsonDictionary;
        if (readinessResult)
        {
            statusString = @"Success";
            result = readinessResult;
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to serialize onboarding readiness response.");
        }
    }
    else if (status == MSIDWebCPOnboardingReadinessResponseStatusNotSupported)
    {
        statusString = @"NotSupported";
        result = @{@"contractVersion": @(MSIDWebCPOnboardingReadinessContractVersion),
                   @"supportedContractVersions": @[@(MSIDWebCPOnboardingReadinessContractVersion)]};
    }
    return @{@"correlationID": correlationID, @"status": statusString, @"result": result};
}

@end
