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

#if !EXCLUDE_FROM_MSALCPP

#import "MSIDDefaultAccount.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJsonSerializer.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDProviderType.h"

@implementation MSIDDefaultAccount

- (instancetype)initWithAccountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                                authority:(MSIDAuthority *)authority
{
    self = [super init];

    if (self)
    {
        _accountIdentifier = accountIdentifier;
        _authority = authority;
    }

    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError *__autoreleasing*)error
{
    self = [super init];

    if (self)
    {
        _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json error:error];
        if (!_accountIdentifier) return nil;
        
        _authority = (MSIDAuthority *)[MSIDJsonSerializableFactory createFromJSONDictionary:json classTypeJSONKey:MSID_PROVIDER_TYPE_JSON_KEY assertKindOfClass:MSIDAuthority.class error:error];
        if (!_authority) return nil;
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    if (!json) return nil;
    
    NSDictionary *accountIdentifierJson = [self.accountIdentifier jsonDictionary];
    if (accountIdentifierJson) [json addEntriesFromDictionary:accountIdentifierJson];
    
    NSDictionary *authorityJson = [self.authority jsonDictionary];
    if (authorityJson) [json addEntriesFromDictionary:authorityJson];
    
    return json;
}

@end

#endif
