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
#import "MSIDAuthority.h"
#import "MSIDJsonSerializable.h"
@protocol MSIDAuthenticationSchemeProtocol;

extern NSString * const MSID_REDIRECT_URI_JSON_KEY;
extern NSString * const MSID_CLIENT_ID_JSON_KEY;
extern NSString * const MSID_SCOPE_JSON_KEY;

@interface MSIDConfiguration : NSObject <NSCopying, MSIDJsonSerializable>

// Commonly used or needed properties
@property (readwrite) MSIDAuthority *authority;
@property (readwrite) NSString *redirectUri;
@property (readwrite) NSString *clientId;
@property (readonly) NSString *target;
@property (readwrite) id<MSIDAuthenticationSchemeProtocol> authScheme;

@property (readwrite) NSString *applicationIdentifier;

@property (readonly) NSString *resource;
@property (readonly) NSOrderedSet<NSString *> *scopes;

- (instancetype)initWithAuthority:(MSIDAuthority *)authority
                      redirectUri:(NSString *)redirectUri
                         clientId:(NSString *)clientId
                           target:(NSString *)target;

- (instancetype)initWithAuthority:(MSIDAuthority *)authority
                      redirectUri:(NSString *)redirectUri
                         clientId:(NSString *)clientId
                         resource:(NSString *)resource
                           scopes:(NSOrderedSet<NSString *> *)scopes;

@end
