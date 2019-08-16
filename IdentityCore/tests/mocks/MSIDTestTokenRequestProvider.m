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

#import "MSIDTestTokenRequestProvider.h"
#import "MSIDTestSilentTokenRequest.h"
#import "MSIDTestInteractiveTokenRequest.h"
#import "MSIDTestBrokerTokenRequest.h"

@interface MSIDTestTokenRequestProvider()

@property (nonatomic) MSIDTokenResult *testTokenResult;
@property (nonatomic) NSError *testError;
@property (nonatomic) MSIDWebWPJResponse *testBrokerResponse;
@property (nonatomic) NSURL *testBrokerRequestURL;
@property (nonatomic) NSDictionary *testResumeDictionary;

@end

@implementation MSIDTestTokenRequestProvider

#pragma mark - Init

- (instancetype)initWithTestResponse:(MSIDTokenResult *)tokenResult
                           testError:(NSError *)error
               testWebMSAuthResponse:(MSIDWebWPJResponse *)brokerResponse
{
    self = [super init];

    if (self)
    {
        _testTokenResult = tokenResult;
        _testError = error;
        _testBrokerResponse = brokerResponse;
    }

    return self;
}

- (instancetype)initWithTestResponse:(MSIDTokenResult *)tokenResult
                           testError:(NSError *)error
               testWebMSAuthResponse:(MSIDWebWPJResponse *)brokerResponse
                    brokerRequestURL:(NSURL *)brokerRequestURL
                    resumeDictionary:(NSDictionary *)brokerResumeDictionary
{
    self = [super init];

    if (self)
    {
        _testTokenResult = tokenResult;
        _testError = error;
        _testBrokerResponse = brokerResponse;
        _testBrokerRequestURL = brokerRequestURL;
        _testResumeDictionary = brokerResumeDictionary;
    }

    return self;
}

#pragma mark - MSIDTokenRequestProviding

- (nullable MSIDInteractiveTokenRequest *)interactiveTokenRequestWithParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
{
    return [[MSIDTestInteractiveTokenRequest alloc] initWithTestResponse:self.testTokenResult
                                                               testError:self.testError
                                                   testWebMSAuthResponse:self.testBrokerResponse];
}

- (nullable MSIDSilentTokenRequest *)silentTokenRequestWithParameters:(nonnull MSIDRequestParameters *)parameters
                                                         forceRefresh:(BOOL)forceRefresh
{
    return [[MSIDTestSilentTokenRequest alloc] initWithTestResponse:self.testTokenResult testError:self.testError];
}


- (nullable MSIDBrokerTokenRequest *)brokerTokenRequestWithParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                                            brokerKey:(nonnull NSString *)brokerKey
                                               brokerApplicationToken:(NSString * _Nullable )brokerApplicationToken
                                                                error:(NSError * _Nullable * _Nullable)error
{
    if (self.testError)
    {
        *error = self.testError;
        return nil;
    }

    return [[MSIDTestBrokerTokenRequest alloc] initWithURL:self.testBrokerRequestURL resumeDictionary:self.testResumeDictionary];
}

@end
