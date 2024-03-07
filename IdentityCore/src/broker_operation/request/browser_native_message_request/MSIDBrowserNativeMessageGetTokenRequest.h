//
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


#import "MSIDBrowserNativeMessageRequest.h"
#import "MSIDConstants.h"

@class MSIDAADAuthority;
@class MSIDAccountIdentifier;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrowserNativeMessageGetTokenRequest : MSIDBrowserNativeMessageRequest

/// uid.utid
@property (nonatomic, nullable) MSIDAccountIdentifier *accountId;

/// Identifies an application that requests a token.
@property (nonatomic) NSString *clientId;

///If it is passed, broker will respect authority, otherwise broker will use default authority.
@property (nonatomic, nullable) MSIDAADAuthority *authority;

/// List of scopes.
@property (nonatomic) NSString *scopes;

/// The redirect uri.
@property (nonatomic) NSString *redirectUri;

/// Indicates the type of user interaction that is required. Valid values are login, none, consent, and select_account.
@property (nonatomic) MSIDPromptType prompt;

/// When this flag is true, broker must take "sender" property and do the authority validation. If it is valid, this call comes from ESTS.
@property (nonatomic) BOOL isSts;

/// Nonce to be embedded in idToken to prevent replay attacks.
@property (nonatomic, nullable) NSString *nonce;

/// OAuth protocol "state" param. It will be returned without changes in the response.
@property (nonatomic, nullable) NSString *state;

/// Upn of the user.
@property (nonatomic, nullable) NSString *loginHint;

/// Clients that support multiple national clouds should set it to true.
@property (nonatomic) BOOL instanceAware;

/// All parameters in this dictionary will be passed on the server-side against both token and authorization endpoints.
@property (nonatomic, nullable) NSDictionary *extraParameters;

@end

NS_ASSUME_NONNULL_END
