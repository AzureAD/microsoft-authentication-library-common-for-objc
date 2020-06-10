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

#import "MSIDBaseToken.h"

@protocol MSIDAuthenticationSchemeProtocol;

@interface MSIDAccessToken : MSIDBaseToken
{
    NSString *_accessToken;
    id<MSIDAuthenticationSchemeProtocol> _authScheme;
    NSString *_tokenType;
}

@property (readwrite) NSDate *expiresOn;
@property (readwrite) NSDate *extendedExpiresOn;
@property (readwrite) NSDate *cachedAt;
@property (readwrite) NSString *accessToken;
@property (readwrite) NSString *tokenType;

// v1 access tokens are scoped down to resources
@property (readwrite) NSString *resource;

// v2 access tokens are scoped down to resources
@property (readwrite) NSOrderedSet<NSString *> *scopes;

// Intune Enrollment ID. Application trying to retrieve access token from cache will need to present a valid intune enrollment ID to complete cache lookup.
@property (readwrite) NSString *enrollmentId;

// Unique app identifier used for cases when access token storage needs to be partitioned per application
@property (readwrite) NSString *applicationIdentifier;

@property id<MSIDAuthenticationSchemeProtocol> authScheme;

- (BOOL)isExpired;
- (BOOL)isExpiredWithExpiryBuffer:(NSUInteger)expiryBuffer;
- (BOOL)isExtendedLifetimeValid;

- (instancetype)initWithAuthScheme:(id<MSIDAuthenticationSchemeProtocol>)authScheme;

@end
