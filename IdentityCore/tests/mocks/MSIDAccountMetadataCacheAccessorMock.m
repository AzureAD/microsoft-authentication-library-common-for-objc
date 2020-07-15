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

#import "MSIDAccountMetadataCacheAccessorMock.h"

@implementation MSIDAccountMetadataCacheAccessorMock

- (NSURL *)getAuthorityURL:(NSURL *)requestAuthorityURL
             homeAccountId:(NSString *)homeAccountId
                  clientId:(NSString *)clientId
             instanceAware:(BOOL)instanceAware
                   context:(__unused id<MSIDRequestContext>)context
                     error:(__unused NSError **)error
{
    self.getAuthorityURLInvokedCount++;
    
    struct MSIDAccountMetadataCacheMockGetAuthorityParameters s = self.getAuthorityProvidedParams;
    s.requestAuthorityURL = requestAuthorityURL;
    s.homeAccountId = homeAccountId;
    s.clientId = clientId;
    s.instanceAware = instanceAware;
    self.getAuthorityProvidedParams = s;
    
    return self.authorityURLToReturn;
}

- (BOOL)updateAuthorityURL:(NSURL *)cacheAuthorityURL
             forRequestURL:(NSURL *)requestAuthorityURL
             homeAccountId:(NSString *)homeAccountId
                  clientId:(NSString *)clientId
             instanceAware:(BOOL)instanceAware
                   context:(__unused id<MSIDRequestContext>)context
                     error:(__unused NSError **)error
{
    self.updateAuthorityURLInvokedCount++;
    
    struct MSIDAccountMetadataCacheMockUpdateAuthorityParameters s = self.updateAuthorityProvidedParams;
    s.cacheAuthorityURL = cacheAuthorityURL;
    s.requestAuthorityURL = requestAuthorityURL;
    s.homeAccountId = homeAccountId;
    s.clientId = clientId;
    s.instanceAware = instanceAware;
    self.updateAuthorityProvidedParams = s;
    
    return YES;
}

- (BOOL)clearForHomeAccountId:(__unused NSString *)homeAccountId
                     clientId:(__unused NSString *)clientId
                      context:(__unused id<MSIDRequestContext>)context
                        error:(__unused NSError **)error
{
    return YES;
}

- (MSIDAccountIdentifier *)principalAccountIdForClientId:(__unused NSString *)clientId
                                                 context:(__unused id<MSIDRequestContext>)context
                                                   error:(NSError **)error
{
    if (error) *error = self.mockedPrincipalAccountIdError;
    return self.mockedPrincipalAccountId;
}

- (BOOL)updatePrincipalAccountIdForClientId:(NSString *)clientId
                         principalAccountId:(MSIDAccountIdentifier *)principalAccountId
                principalAccountEnvironment:(NSString *)principalAccountEnvironment
                                    context:(__unused id<MSIDRequestContext>)context
                                      error:(NSError **)error
{
    if (error) *error = self.updatePrincipalAccountIdError;
    
    struct MSIDAccountMetadataCacheMockUpdatePrincipalAccountIdParams s  = self.updatePrincipalAccountIdParams;
    s.principalAccountId = principalAccountId;
    s.clientId = clientId;
    s.accountEnvironment = principalAccountEnvironment;
    self.updatePrincipalAccountIdParams = s;
    
    self.updatePrincipalAccountIdInvokedCount++;
    
    return self.updatePrincipalAccountIdResult;
}

- (BOOL)removeAccountMetadataForHomeAccountId:(NSString *)homeAccountId
                                      context:(id<MSIDRequestContext>)context
                                        error:(NSError **)error
{
    if (error) *error = self.removeAccountMetadataForHomeAccountIdError;
    
    struct MSIDAccountMetadataCacheMockRemoveAccountMetadataForHomeAccountIdParams s  = self.removeAccountMetadataForHomeAccountIdParams;
    s.homeAccountId = homeAccountId;
    self.removeAccountMetadataForHomeAccountIdParams = s;
    
    self.removeAccountMetadataForHomeAccountIdInvokedCount++;
    
    return self.removeAccountMetadataForHomeAccountIdResult;
}

@end
