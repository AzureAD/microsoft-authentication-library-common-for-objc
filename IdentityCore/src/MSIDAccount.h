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
#import "MSIDTokenResponse.h"
#import "MSIDBaseCacheItem.h"
#import "MSIDCacheItem.h"

typedef NS_ENUM(NSInteger, MSIDAccountType)
{
    MSIDAccountTypeAADV1 = 1,
    MSIDAccountTypeMSA = 2,
    MSIDAccountTypeAADV2 = 3,
    MSIDAccountTypeOther = 4
};

@interface MSIDAccount : MSIDBaseCacheItem

// Legacy user identifier
@property (nonatomic) NSString *legacyUserId;
@property (nonatomic) NSString *utid;
@property (nonatomic) NSString *uid;

// Primary user identifier
@property (readonly) NSString *userIdentifier;

@property (readonly) MSIDAccountType accountType;
@property (readonly) NSString *firstName;
@property (readonly) NSString *lastName;
@property (readonly) NSDictionary *additionalFields;

- (instancetype)initWithUpn:(NSString *)upn
                       utid:(NSString *)utid
                        uid:(NSString *)uid;

- (void)updateFieldsFromAccount:(MSIDAccount *)account;

@end
