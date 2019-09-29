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
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
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
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
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

- (BOOL)clearForHomeAccountId:(NSString *)homeAccountId
                     clientId:(NSString *)clientId
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    return YES;
}

@end
