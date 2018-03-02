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

#import "MSIDTokenResponseHandler.h"
#import "MSIDTokenResponse.h"
#import "MSIDRequestContext.h"
#import "MSIDError.h"
#import "MSIDClientInfo.h"

@implementation MSIDTokenResponseHandler

+ (BOOL)verifyResponse:(MSIDTokenResponse *)response
      fromRefreshToken:(BOOL)fromRefreshToken
               context:(id<MSIDRequestContext>)context
                 error:(NSError * __autoreleasing *)error
{
    if (!response)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInternal, @"processTokenResponse called without a response dictionary", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    if (response.error)
    {
        if (error)
        {
            *error = [response getOAuthError:context fromRefreshToken:fromRefreshToken];
        }
        return NO;
    }
    
    if ([NSString msidIsStringNilOrBlank:response.accessToken])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Authentication response received without expected accessToken", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    NSError *errorFromExtendedProperties = [response verifyExtendedProperties:context];
    if (errorFromExtendedProperties)
    {
        if (error)
        {
            *error = errorFromExtendedProperties;
        }
        return NO;
    }
    
    // TODO: ADAL and MSAL are checking if user matches in different places. Discuss if we should move that logic to this function
    
    return YES;
}

@end

