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


#import "MSIDWebResponseBrokerInstallOperation.h"
#import "MSIDWebviewResponse.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDTokenRequestProviding.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDAccountMetadataCacheAccessor.h"

#if TARGET_OS_IPHONE
    #import "MSIDAppExtensionUtil.h"
#endif

@interface MSIDWebResponseBrokerInstallOperation()

@property (nonatomic) NSURL *appInstallLink;

@end

@implementation MSIDWebResponseBrokerInstallOperation

- (nullable instancetype)initWithResponse:(MSIDWebviewResponse *)response
                                    error:(NSError **)error
{
    #if TARGET_OS_IPHONE
        self = [super initWithResponse:response
                                 error:error];
        if (self)
        {
            if (![response isKindOfClass:MSIDWebWPJResponse.class] || [NSString msidIsStringNilOrBlank:[(MSIDWebWPJResponse *)response appInstallLink]])
            {
                return nil;
            }
            
            MSIDWebWPJResponse *wpjResponse = (MSIDWebWPJResponse *)response;
            _appInstallLink = [NSURL URLWithString:wpjResponse.appInstallLink];
        }
        
        return self;
    #else
        return nil;
    #endif
}

- (void)invokeWithInteractiveTokenRequestParameters:(MSIDInteractiveRequestParameters *)interactiveTokenRequestParameters
                               tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                         completion:(MSIDRequestCompletionBlock)completion
{
    if (!completion)
    {
        return;
    }
    
    #if TARGET_OS_IPHONE
        if ([interactiveTokenRequestParameters isKindOfClass:MSIDInteractiveTokenRequestParameters.class])
        {
            NSError *brokerError;
            MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:(MSIDInteractiveTokenRequestParameters *)interactiveTokenRequestParameters
                                                                                                                         tokenRequestProvider:tokenRequestProvider
                                                                                                                            brokerInstallLink:self.appInstallLink
                                                                                                                                        error:&brokerError];
            [brokerController acquireToken:completion];
        } else
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Wrong type of interactive request parameter", nil, nil, nil, nil, nil, YES);
            completion(nil, error);
        }
    #else
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Trying to install broker on macOS, where it's not currently supported", nil, nil, nil, nil, nil, YES);
        completion(nil, error);
    #endif
}

@end
