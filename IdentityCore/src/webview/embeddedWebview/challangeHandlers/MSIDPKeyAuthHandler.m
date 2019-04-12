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

#import "MSIDPKeyAuthHandler.h"
#import "MSIDChallengeHandler.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDPkeyAuthHelper.h"
#import "MSIDHelpers.h"
#import "MSIDError.h"
#import "MSIDDeviceId.h"
#import "MSIDConstants.h"
#import "NSDictionary+MSIDExtensions.h"

@implementation MSIDPKeyAuthHandler

+ (BOOL)handleChallenge:(NSString *)challengeUrl
                context:(id<MSIDRequestContext>)context
      completionHandler:(void (^)(NSURLRequest *challengeResponse, NSError *error))completionHandler
{
    MSID_LOG_INFO(context, @"Handling PKeyAuth Challenge.");
    
    NSArray *parts = [challengeUrl componentsSeparatedByString:@"?"];
    NSString *qp = [parts objectAtIndex:1];
    NSDictionary *queryParamsMap = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:qp];
    NSString *submitUrl = [queryParamsMap valueForKey:@"SubmitUrl"];
    
    // Fail if the PKeyAuth challenge doesn't contain the required info
    NSError *error = nil;
    if (!queryParamsMap || !submitUrl)
    {
        error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerOauth, @"Incomplete PKeyAuth challenge received.", nil, nil, nil, context.correlationId, nil);
        completionHandler(nil, error);
        return YES;
    }
    
    // Extract authority from submit url
    NSArray *authorityParts = [submitUrl componentsSeparatedByString:@"?"];
    NSString *authority = [authorityParts objectAtIndex:0];
    
    NSString *authHeader = [MSIDPkeyAuthHelper createDeviceAuthResponse:authority
                                                          challengeData:queryParamsMap
                                                                context:context];
    
    // Attach client version to response url
    NSURLComponents *responseUrlComp = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:submitUrl] resolvingAgainstBaseURL:NO];
    NSMutableDictionary *queryDict = [NSMutableDictionary new];
    
    for (NSURLQueryItem *item in responseUrlComp.queryItems)
    {
        [queryDict setValue:item.value forKey:item.name];
    }
    [queryDict setValue:MSIDDeviceId.deviceId[MSID_VERSION_KEY] forKey:MSID_VERSION_KEY];
    responseUrlComp.percentEncodedQuery = [queryDict msidWWWFormURLEncode];
    
    NSMutableURLRequest *responseReq = [[NSMutableURLRequest alloc] initWithURL:responseUrlComp.URL];
    [responseReq setValue:kMSIDPKeyAuthHeaderVersion forHTTPHeaderField:kMSIDPKeyAuthHeader];
    [responseReq setValue:authHeader forHTTPHeaderField:MSID_OAUTH2_AUTHORIZATION];
    completionHandler(responseReq, nil);
    return YES;
}

@end
