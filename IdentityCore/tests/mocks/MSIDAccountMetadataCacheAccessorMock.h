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

NS_ASSUME_NONNULL_BEGIN

struct MSIDAccountMetadataCacheMockUpdateAuthorityParameters
{
    NSURL * _Nullable cacheAuthorityURL;
    NSURL * _Nullable requestAuthorityURL;
    NSString * _Nullable homeAccountId;
    NSString *_Nullable clientId;
    BOOL instanceAware;
};

struct MSIDAccountMetadataCacheMockGetAuthorityParameters
{
    NSURL * _Nullable requestAuthorityURL;
    NSString * _Nullable homeAccountId;
    NSString *_Nullable clientId;
    BOOL instanceAware;
};

struct MSIDAccountMetadataCacheMockUpdatePrincipalAccountIdParams
{
    MSIDAccountIdentifier * _Nullable principalAccountId;
    NSString * _Nullable clientId;
    NSString * _Nullable accountEnvironment;
};

@interface MSIDAccountMetadataCacheAccessorMock : MSIDAccountMetadataCacheAccessor

@property (nonatomic) NSInteger updateAuthorityURLInvokedCount;
@property (nonatomic) struct MSIDAccountMetadataCacheMockUpdateAuthorityParameters updateAuthorityProvidedParams;

@property (nonatomic) NSInteger getAuthorityURLInvokedCount;
@property (nonatomic) struct MSIDAccountMetadataCacheMockGetAuthorityParameters getAuthorityProvidedParams;
@property (nonatomic) NSURL *authorityURLToReturn;

@property (nonatomic, nullable) MSIDAccountIdentifier *mockedPrincipalAccountId;
@property (nonatomic, nullable) NSError *mockedPrincipalAccountIdError;

@property (nonatomic) BOOL updatePrincipalAccountIdResult;
@property (nonatomic) NSError *updatePrincipalAccountIdError;
@property (nonatomic) NSInteger updatePrincipalAccountIdInvokedCount;
@property (nonatomic) struct MSIDAccountMetadataCacheMockUpdatePrincipalAccountIdParams updatePrincipalAccountIdParams;

@end

NS_ASSUME_NONNULL_END
