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

#import "MSIDBrokerOperationPasskeyAssertionRequest.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"

NSString *const MSID_PASSKEY_ASSERTION_CLIENT_DATA_HASH_KEY = @"clientDataHash";
NSString *const MSID_PASSKEY_ASSERTION_RELYING_PARTY_ID_KEY = @"relyingPartyId";
NSString *const MSID_PASSKEY_ASSERTION_KEY_ID_KEY = @"keyId";

@implementation MSIDBrokerOperationPasskeyAssertionRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_PASSKEY_ASSERTION;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        _clientDataHash = [[json msidStringObjectForKey:MSID_PASSKEY_ASSERTION_CLIENT_DATA_HASH_KEY] msidHexData];
        _relyingPartyId = [json msidStringObjectForKey:MSID_PASSKEY_ASSERTION_RELYING_PARTY_ID_KEY];
        _keyId = [[json msidStringObjectForKey:MSID_PASSKEY_ASSERTION_KEY_ID_KEY] msidHexData];
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];

    json[MSID_PASSKEY_ASSERTION_CLIENT_DATA_HASH_KEY] = [self.clientDataHash msidHexString];
    json[MSID_PASSKEY_ASSERTION_RELYING_PARTY_ID_KEY] = self.relyingPartyId;
    json[MSID_PASSKEY_ASSERTION_KEY_ID_KEY] = [self.keyId msidHexString];

    return json;
}

@end

#endif
