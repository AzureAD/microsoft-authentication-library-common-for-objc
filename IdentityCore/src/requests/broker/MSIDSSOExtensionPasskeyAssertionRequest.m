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

#if !EXCLUDE_FROM_MSALCPP

#import "MSIDSSOExtensionPasskeyAssertionRequest.h"
#import "MSIDBrokerOperationPasskeyAssertionRequest.h"
#import "MSIDBrokerOperationGetPasskeyAssertionResponse.h"
#import "MSIDSSOExtensionGetDataBaseRequest+Internal.h"
#import "MSIDPasskeyAssertion.h"

@interface MSIDSSOExtensionPasskeyAssertionRequest()

@property (nonatomic, copy) MSIDPasskeyAssertionRequestCompletionBlock requestCompletionBlock;

@end

@implementation MSIDSSOExtensionPasskeyAssertionRequest

- (instancetype)initWithRequestParameters:(MSIDRequestParameters *)requestParameters
                           clientDataHash:(NSData *)clientDataHash
                           relyingPartyId:(NSString *)relyingPartyId
                                    keyId:(NSData *)keyId
                            correlationId:(NSUUID *)correlationId
                                    error:(NSError **)error
{
    self = [super initWithRequestParameters:requestParameters error:error];
    if (self)
    {
        _clientDataHash = clientDataHash;
        _relyingPartyId = relyingPartyId;
        _keyId = keyId;
        _correlationId = correlationId;

        __typeof__(self) __weak weakSelf = self;
        self.extensionDelegate.completionBlock = ^(MSIDBrokerNativeAppOperationResponse *operationResponse, NSError *resultError)
        {
            __strong __typeof__(self) strongSelf = weakSelf;
            MSIDPasskeyAssertion *passkeyAssertion = nil;

            if (!operationResponse.success)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, requestParameters, @"Finished get passkey assertion request with error %@", MSID_PII_LOG_MASKABLE(resultError));
            }
            else if (![operationResponse isKindOfClass:[MSIDBrokerOperationGetPasskeyAssertionResponse class]])
            {
                resultError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Received incorrect response type for the get passkey assertion request", nil, nil, nil, nil, nil, YES);
            }
            else
            {
                MSIDBrokerOperationGetPasskeyAssertionResponse *response = (MSIDBrokerOperationGetPasskeyAssertionResponse *)operationResponse;
                passkeyAssertion = response.passkeyAssertion;
            }

            MSIDPasskeyAssertionRequestCompletionBlock completionBlock = strongSelf.requestCompletionBlock;
            strongSelf.requestCompletionBlock = nil;

            if (completionBlock) completionBlock(passkeyAssertion, resultError);
        };

        self.ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
    }

    return self;
}

- (void)executeRequestWithCompletion:(MSIDPasskeyAssertionRequestCompletionBlock)completionBlock
{
    MSIDBrokerOperationPasskeyAssertionRequest *passkeyAssertionRequest = [MSIDBrokerOperationPasskeyAssertionRequest new];
    passkeyAssertionRequest.clientDataHash = self.clientDataHash;
    passkeyAssertionRequest.relyingPartyId = self.relyingPartyId;
    passkeyAssertionRequest.keyId = self.keyId;
    passkeyAssertionRequest.correlationId = self.correlationId ?: [NSUUID UUID];

    self.requestCompletionBlock = completionBlock;
    [self executeBrokerOperationRequest:passkeyAssertionRequest requiresUI:NO errorBlock:^(NSError *error) {
        if(completionBlock) completionBlock(nil, error);
    }];
}

@end

#endif
