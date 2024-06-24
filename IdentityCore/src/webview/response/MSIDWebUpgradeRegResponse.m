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

#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDClientInfo.h"
#import "MSIDWebResponseOperationConstants.h"
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDWebResponseBrokerInstallOperation.h"
#import "MSIDWebWPJResponse+Internal.h"

@implementation MSIDWebUpgradeRegResponse

+ (void)load
{
    [MSIDWebResponseOperationFactory registerOperationClass:MSIDWebResponseBrokerInstallOperation.class forResponseClass:self];
}

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    // Check for upgrade registration
    if (![self isBrokerInstallResponse:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     @"WPJ response should have msauth as a scheme and wpj/broker as a host",
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    return [super initResponseWithURL:url context:context error:error];
}

- (BOOL)isBrokerInstallResponse:(NSURL *)url
{
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    
    // For embedded webview, if link starts with msauth scheme and contain upgradeReg host
    // then it is migrateWpj request
    // e.g. msauth://upgradeReg?param=param
    if ([scheme isEqualToString:@"msauth"] && [host isEqualToString:@"upgradeReg"]) //$todo upgradeReg
    {
        return YES;
    }

    NSArray *pathComponents = url.pathComponents;
    
    if ([pathComponents count] < 2)
    {
        return NO;
    }
    
    // For system webview, this link will start with the redirect uri and will have msauth and upgradeReg as path parameters
    // e.g. myscheme://auth/msauth/upgradeReg?param=param
    NSUInteger pathComponentCount = pathComponents.count;
    
    if ([pathComponents[pathComponentCount - 1] isEqualToString:@"upgradeReg"]
        && [pathComponents[pathComponentCount - 2] isEqualToString:@"msauth"])
    {
        return YES;
    }

    return NO;
}

+ (NSString *)operation
{
    return MSID_UPGRADE_REGISTRATION_BROKER_OPERATION;
}

@end
