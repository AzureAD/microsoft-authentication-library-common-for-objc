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

#import "MSIDAccountMetadataCacheAccessor.h"

@class MSIDAccountMetadataCacheMockUpdateAuthorityParameters;
@class MSIDAccountMetadataCacheMockGetAuthorityParameters;
@class MSIDAccountMetadataCacheMockUpdatePrincipalAccountIdParams;
@class MSIDAccountMetadataCacheMockRemoveAccountMetadataForHomeAccountIdParams;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAccountMetadataCacheAccessorMock : MSIDAccountMetadataCacheAccessor

@property (nonatomic) NSInteger updateAuthorityURLInvokedCount;
@property (nonatomic) MSIDAccountMetadataCacheMockUpdateAuthorityParameters *updateAuthorityProvidedParams;

@property (nonatomic) NSInteger getAuthorityURLInvokedCount;
@property (nonatomic) MSIDAccountMetadataCacheMockGetAuthorityParameters *getAuthorityProvidedParams;
@property (nonatomic) NSURL *authorityURLToReturn;

@property (nonatomic, nullable) MSIDAccountIdentifier *mockedPrincipalAccountId;
@property (nonatomic, nullable) NSError *mockedPrincipalAccountIdError;

@property (nonatomic) BOOL updatePrincipalAccountIdResult;
@property (nonatomic) NSError *updatePrincipalAccountIdError;
@property (nonatomic) NSInteger updatePrincipalAccountIdInvokedCount;
@property (nonatomic) MSIDAccountMetadataCacheMockUpdatePrincipalAccountIdParams *updatePrincipalAccountIdParams;

@property (nonatomic) BOOL removeAccountMetadataForHomeAccountIdResult;
@property (nonatomic) NSError *removeAccountMetadataForHomeAccountIdError;
@property (nonatomic) NSInteger removeAccountMetadataForHomeAccountIdInvokedCount;
@property (nonatomic) MSIDAccountMetadataCacheMockRemoveAccountMetadataForHomeAccountIdParams *removeAccountMetadataForHomeAccountIdParams;


@end

NS_ASSUME_NONNULL_END
