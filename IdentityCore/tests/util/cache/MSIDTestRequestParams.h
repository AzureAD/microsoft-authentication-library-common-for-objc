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

#import <Foundation/Foundation.h>

@class MSIDAADV1RequestParameters;
@class MSIDAADV2RequestParameters;
@class MSIDRequestParameters;

@interface MSIDTestRequestParams : NSObject

+ (MSIDRequestParameters *)defaultParams;

+ (MSIDRequestParameters *)defaultParamsWithAuthority:(NSString *)authority
                                             clientId:(NSString *)clientId;

+ (MSIDAADV1RequestParameters *)v1DefaultParams;

+ (MSIDAADV1RequestParameters *)v1ParamsWithAuthority:(NSString *)authority
                                             clientId:(NSString *)clientId
                                             resource:(NSString *)resource;

+ (MSIDAADV2RequestParameters *)v2DefaultParams;

+ (MSIDAADV2RequestParameters *)v2DefaultParamsWithScopes:(NSOrderedSet<NSString *> *)scopes;
+ (MSIDAADV2RequestParameters *)v2ParamsWithAuthority:(NSURL *)authority
                                          redirectUri:(NSString *)redirectUri
                                             clientId:(NSString *)clientId
                                               scopes:(NSOrderedSet<NSString *> *)scopes;

@end
