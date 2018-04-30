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

#import "MSIDB2CAuthorityResolver.h"
#import "MSIDAuthority.h"

@implementation MSIDB2CAuthorityResolver

- (void)discoverAuthority:(NSURL *)authority
        userPrincipalName:(NSString *)upn
                 validate:(BOOL)validate
                  context:(id<MSIDRequestContext>)context
          completionBlock:(MSIDAuthorityInfoBlock)completionBlock
{
    if (validate && ![MSIDAuthority isKnownHost:authority])
    {
        __auto_type error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidRequest, @"Authority validation is not supported for this type of authority", nil, nil, nil, context.correlationId, nil);
        completionBlock(nil, nil, NO, error);
        return;
    }
    
    completionBlock(authority, [self defaultOpenIdConfigurationEndpointForAuthority:authority], validate, nil);
}

@end
