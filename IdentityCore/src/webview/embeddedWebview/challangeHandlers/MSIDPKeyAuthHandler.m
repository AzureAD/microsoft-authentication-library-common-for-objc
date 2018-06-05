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

@implementation MSIDPKeyAuthHandler

+ (BOOL)handleChallenge:(NSString *)challengeUrl
                context:(id<MSIDRequestContext>)context
      completionHandler:(void (^)(NSURLRequest *challengeResponse, NSError *error))completionHandler
{
    MSID_LOG_INFO(context, @"Handling PKeyAuth Challenge.");
    
    NSArray *parts = [challengeUrl componentsSeparatedByString:@"?"];
    NSString *qp = [parts objectAtIndex:1];
    NSDictionary *queryParamsMap = [NSDictionary msidURLFormDecode:qp];
    NSString *submitUrl = [MSIDHelpers msidAddClientVersionToURLString:[queryParamsMap valueForKey:@"SubmitUrl"]];
    
    NSArray *authorityParts = [submitUrl componentsSeparatedByString:@"?"];
    NSString *authority = [authorityParts objectAtIndex:0];
    
    NSError *error = nil;
    NSString *authHeader = [MSIDPkeyAuthHelper createDeviceAuthResponse:authority
                                                          challengeData:queryParamsMap
                                                                context:context
                                                                  error:&error];
    if (!authHeader)
    {
        completionHandler(nil, error);
        return NO;
    }
    
    NSMutableURLRequest *responseUrl = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:submitUrl]];
    
    [responseUrl setValue:kMSIDPKeyAuthHeaderVersion forHTTPHeaderField:kMSIDPKeyAuthHeader];
    [responseUrl setValue:authHeader forHTTPHeaderField:@"Authorization"];
    completionHandler(responseUrl, nil);
    return YES;
}

@end
