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

#import "MSIDBrokerExtensionTokenRequestController+Internal.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDJsonSerializer.h"

@implementation MSIDBrokerExtensionTokenRequestController

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    
}

+ (BOOL)canPerformRequest
{
    // TODO: check for extension.
    return YES;
}

#pragma mark - ASAuthorizationControllerDelegate

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization
{
    // TODO: hack
    ASAuthorizationSingleSignOnCredential *ssoCredential = (ASAuthorizationSingleSignOnCredential *)authorization.credential;
    
    NSDictionary *response = ssoCredential.authenticatedResponse.allHeaderFields;
    
    NSString *jsonString = response[@"response"];
    NSDictionary *json = (NSDictionary *)[[MSIDJsonSerializer new] fromJsonString:jsonString ofType:NSDictionary.class context:nil error:nil];
    
    __unused NSString *operation = json[@"operation"];
    
    NSError *localError;
    __unused MSIDBrokerOperationTokenResponse *operationResponse = [[MSIDBrokerOperationTokenResponse alloc] initWithJSONDictionary:json error:&localError];
    
    if (localError)
    {
        // TODO: handle error;
    }
    
    assert(self.requestCompletionBlock);
    self.requestCompletionBlock(operationResponse.result, operationResponse.error);
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error
{
    // TODO: handle error
}

#pragma mark - Private

+ (ASAuthorizationSingleSignOnProvider *)sharedProvider
{
    static dispatch_once_t once;
    static ASAuthorizationSingleSignOnProvider *ssoProvider;
    
    dispatch_once(&once, ^{
        // TODO: use authority.
        NSURL *url = [NSURL URLWithString:@"https://ios-sso-test.azurewebsites.net"];
    
        ssoProvider = [ASAuthorizationSingleSignOnProvider authorizationProviderWithIdentityProviderURL:url];
    });
    
    return ssoProvider;
}

@end
