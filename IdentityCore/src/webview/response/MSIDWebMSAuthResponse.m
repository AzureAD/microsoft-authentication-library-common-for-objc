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

#import "MSIDWebMSAuthResponse.h"

@implementation MSIDWebMSAuthResponse

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    
    // Check for WPJ or broker response
    if (!([scheme isEqualToString:@"msauth"] && [host isEqualToString:@"wpj"]))
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     @"WPJ response should have msauth as a scheme and wpj/broker as a host",
                                     nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        _appInstallLink = self.parameters[@"app_link"];
        _upn = self.parameters[@"upn"];
    }
    
    return self;
}



@end
