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

#import "MSIDBrokerOperationRequest.h"
#import "MSIDProviderType.h"

@class MSIDRequestParameters;
@class MSIDConfiguration;
@class MSIDClaimsRequest;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationTokenRequest : MSIDBrokerOperationRequest

@property (nonatomic) MSIDConfiguration *configuration;
@property (nonatomic) MSIDProviderType providerType;
@property (nonatomic, nullable) NSString *oidcScope;
@property (nonatomic, nullable) NSDictionary *extraQueryParameters;
@property (nonatomic) BOOL allowAnyExtraURLQueryParameters;
@property (nonatomic) BOOL instanceAware;
@property (nonatomic, nullable) NSDictionary *enrollmentIds;
@property (nonatomic, nullable) NSDictionary *mamResources;
@property (nonatomic, nullable) NSArray *clientCapabilities;
@property (nonatomic, nullable) MSIDClaimsRequest *claimsRequest;
@property (nonatomic) NSDate *requestSentDate;
@property (nonatomic) NSString *nonce;
@property (nonatomic) NSString *webPageUri;
@property (nonatomic, nullable) NSString *accountHomeTenantId;
@property (nonatomic, nullable) NSString *clientSku;
@property (nonatomic) BOOL skipValidateResultAccount;
@property (nonatomic) BOOL forceRefresh;
@property (nonatomic) BOOL ignoreScopeValidation;


+ (BOOL)fillRequest:(MSIDBrokerOperationTokenRequest *)request
     withParameters:(MSIDRequestParameters *)parameters
       providerType:(MSIDProviderType)providerType
      enrollmentIds:(nullable NSDictionary *)enrollmentIds
       mamResources:(nullable NSDictionary *)mamResources
    requestSentDate:(NSDate *)requestSentDate;

@end

NS_ASSUME_NONNULL_END
