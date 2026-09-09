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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDWebviewResponse.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"
#import "MSIDOAuth2Constants.h"
#import "NSString+MSIDExtensions.h"

typedef NS_ENUM(NSInteger, MSIDWebResponseStateResult)
{
    MSIDWebResponseStateResultMatched = 0,
    MSIDWebResponseStateResultMissing,
    MSIDWebResponseStateResultUnexpected,
    MSIDWebResponseStateResultMalformed,
    MSIDWebResponseStateResultMismatched,
    MSIDWebResponseStateResultDuplicate,
    MSIDWebResponseStateResultNotExpectedAndAbsent
};

@interface MSIDWebviewResponse (StateValidation)

+ (NSArray<NSString *> *)stateValuesFromResponseURL:(NSURL *)responseURL;

+ (void)appendStateValuesFromQueryItems:(NSArray<NSURLQueryItem *> *)queryItems
                                toArray:(NSMutableArray<NSString *> *)stateValues;

+ (MSIDWebResponseStateResult)stateResultForValues:(NSArray<NSString *> *)stateValues
                                     expectedState:(NSString *)expectedState;

+ (NSString *)stringForStateResult:(MSIDWebResponseStateResult)result;

@end

@implementation MSIDWebviewResponse

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    if (!url)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     @"Trying to create a response with nil URL",
                                     nil, nil, nil, context.correlationId, nil, YES);
        }
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _url = url;
        
        // Check for auth response
        _parameters = [self.class msidWebResponseParametersFromURL:url];
    }
    
    return self;
}

+ (NSDictionary *)msidWebResponseParametersFromURL:(NSURL *)url
{
    NSMutableDictionary *responseParameters = [NSMutableDictionary new];
    
    /*
     Note that here we only really need to look for query parameters, since this SDK operates based on authorization code grant.
     By default, resulting authorization code will be returned in the query parameters for authorization code grant unless request specifies a different response_mode parameter, which it doesn't in this case.
     
     However, the code to check for fragments has been in ADALs since 2014 and this class will be also used by ADALs. There're two possible reasons why this code was necessary:
     1. Clients sent response_mode=fragment in the extra query parameters and it worked because of ADALs handling.
     2. Some older ADFS version didn't correctly implement the default response mode.
     
     Therefore, the code to read fragment contents will be kept for backward compatibility reasons until determined 100% unnecessary by any clients.
     */
    [responseParameters addEntriesFromDictionary:[url msidFragmentParameters]];
    [responseParameters addEntriesFromDictionary:[url msidQueryParameters]];
    return responseParameters;
}

+ (BOOL)validateRequestState:(NSString *)requestState
                 responseURL:(NSURL *)responseURL
                responseType:(NSString *)responseType
                responseForm:(NSString *)responseForm
      ignoreInvalidStateFlag:(BOOL)ignoreInvalidState
                     enforce:(BOOL)enforce
                     context:(id<MSIDRequestContext>)context
                       error:(NSError *__autoreleasing *)error
{
    NSArray<NSString *> *stateValues = [self stateValuesFromResponseURL:responseURL];
    MSIDWebResponseStateResult result = [self stateResultForValues:stateValues
                                                    expectedState:requestState];
    NSString *resultString = [self stringForStateResult:result];

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo,
                      context,
                      @"Special web response state validation: type=%@ form=%@ result=%@ mode=%@ expected_state_present=%@ response_state_present=%@ legacy_ignore_requested=%@",
                      responseType,
                      responseForm,
                      resultString,
                      enforce ? @"enforce" : @"report",
                      [NSString msidIsStringNilOrBlank:requestState] ? @"no" : @"yes",
                      stateValues.count ? @"yes" : @"no",
                      ignoreInvalidState ? @"yes" : @"no");

    BOOL validResult = result == MSIDWebResponseStateResultMatched
        || result == MSIDWebResponseStateResultNotExpectedAndAbsent;
    if (validResult || !enforce)
    {
        return YES;
    }

    if (error)
    {
        *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                 MSIDErrorServerInvalidState,
                                 [NSString stringWithFormat:@"Special web response failed request-state validation (%@).", resultString],
                                 nil,
                                 [NSString stringWithFormat:@"special_web_response_state_%@", resultString],
                                 nil,
                                 context.correlationId,
                                 nil,
                                 YES);
    }

    return NO;
}

+ (NSArray<NSString *> *)stateValuesFromResponseURL:(NSURL *)responseURL
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:responseURL
                                                resolvingAgainstBaseURL:NO];
    NSMutableArray<NSString *> *stateValues = [NSMutableArray new];

    [self appendStateValuesFromQueryItems:components.queryItems
                                  toArray:stateValues];

    if (components.percentEncodedFragment.length)
    {
        NSURLComponents *fragmentComponents = [NSURLComponents new];
        fragmentComponents.percentEncodedQuery = components.percentEncodedFragment;
        [self appendStateValuesFromQueryItems:fragmentComponents.queryItems
                                      toArray:stateValues];
    }

    return stateValues;
}

+ (void)appendStateValuesFromQueryItems:(NSArray<NSURLQueryItem *> *)queryItems
                                toArray:(NSMutableArray<NSString *> *)stateValues
{
    for (NSURLQueryItem *queryItem in queryItems)
    {
        if ([queryItem.name isEqualToString:MSID_OAUTH2_STATE])
        {
            [stateValues addObject:queryItem.value ?: @""];
        }
    }
}

+ (MSIDWebResponseStateResult)stateResultForValues:(NSArray<NSString *> *)stateValues
                                     expectedState:(NSString *)expectedState
{
    if (stateValues.count > 1)
    {
        return MSIDWebResponseStateResultDuplicate;
    }

    BOOL expectedStatePresent = ![NSString msidIsStringNilOrBlank:expectedState];
    NSString *receivedState = stateValues.firstObject;

    if (!expectedStatePresent && !receivedState)
    {
        return MSIDWebResponseStateResultNotExpectedAndAbsent;
    }

    if (!receivedState)
    {
        return MSIDWebResponseStateResultMissing;
    }

    if ([NSString msidIsStringNilOrBlank:receivedState])
    {
        return MSIDWebResponseStateResultMalformed;
    }

    NSString *decodedState = receivedState.msidBase64UrlDecode;
    if (!decodedState)
    {
        return MSIDWebResponseStateResultMalformed;
    }

    if (!expectedStatePresent)
    {
        return MSIDWebResponseStateResultUnexpected;
    }

    return [decodedState isEqualToString:expectedState]
        ? MSIDWebResponseStateResultMatched
        : MSIDWebResponseStateResultMismatched;
}

+ (NSString *)stringForStateResult:(MSIDWebResponseStateResult)result
{
    switch (result)
    {
        case MSIDWebResponseStateResultMatched:
            return @"matched";

        case MSIDWebResponseStateResultMissing:
            return @"missing";

        case MSIDWebResponseStateResultUnexpected:
            return @"unexpected";

        case MSIDWebResponseStateResultMalformed:
            return @"malformed";

        case MSIDWebResponseStateResultMismatched:
            return @"mismatched";

        case MSIDWebResponseStateResultDuplicate:
            return @"duplicate";

        case MSIDWebResponseStateResultNotExpectedAndAbsent:
            return @"not_expected_absent";
    }

    return @"unknown";
}

+ (NSString *)operation
{
    return @"";
}

- (BOOL)useV2WebResponseHandling
{
    return [MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_USE_V2_WEB_RESPONSE_FACTORY];;
}

@end
