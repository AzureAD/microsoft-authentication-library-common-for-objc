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

#import "MSIDAccountType.h"
#import "MSIDJsonSerializable.h"

@class MSIDClientInfo;

@interface MSIDAccountCacheItem : NSObject <NSCopying, MSIDJsonSerializable>

@property (readwrite) MSIDAccountType accountType;
@property (readwrite, nonnull) NSString *homeAccountId;
@property (readwrite, nonnull) NSString *environment;
@property (readwrite, nullable) NSString *localAccountId;
@property (readwrite, nullable) NSString *username;
@property (readwrite, nullable) NSString *givenName;
@property (readwrite, nullable) NSString *middleName;
@property (readwrite, nullable) NSString *familyName;
@property (readwrite, nullable) NSString *name;
@property (readwrite, nullable) NSString *realm;
@property (readwrite, nullable) MSIDClientInfo *clientInfo;
@property (readwrite, nullable) NSString *alternativeAccountId;

@property (readwrite, nullable) NSDictionary *additionalAccountFields;

// Last Modification info (currently used on macOS only)
@property (readwrite, nullable) NSString *lastModificationTime;
@property (readwrite, nullable) NSString *lastModificationProcess;
@property (readwrite, nullable) NSString *lastModificationApp;

- (void)updateFieldsFromAccount:(nonnull MSIDAccountCacheItem *)account;

@end
