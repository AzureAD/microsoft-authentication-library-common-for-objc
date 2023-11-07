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

#import "MSIDPasskeyAssertion.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJsonSerializer.h"

NSString *const MSID_BROKER_PASSKEY_ASSERTION_SIGNATURE_JSON_KEY = @"signature";
NSString *const MSID_BROKER_PASSKEY_ASSERTION_AUTHENTICATOR_DATA_JSON_KEY = @"authenticatorData";
NSString *const MSID_BROKER_PASSKEY_ASSERTION_CREDENTIAL_ID_JSON_KEY = @"credentialId";

@implementation MSIDPasskeyAssertion

- (instancetype)initWithSignature:(NSData *)signature
                authenticatorData:(NSData *)authenticatorData
                     credentialId:(NSData *)credentialId
{
    self = [super init];

    if (self)
    {
        _signature = signature;
        _authenticatorData = authenticatorData;
        _credentialId = credentialId;
    }

    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError **)error
{
    self = [super init];

    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_PASSKEY_ASSERTION_SIGNATURE_JSON_KEY required:YES error:error]) return nil;
        if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_PASSKEY_ASSERTION_AUTHENTICATOR_DATA_JSON_KEY required:YES error:error]) return nil;
        if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_PASSKEY_ASSERTION_CREDENTIAL_ID_JSON_KEY required:YES error:error]) return nil;
        
        _signature = [[json msidStringObjectForKey:MSID_BROKER_PASSKEY_ASSERTION_SIGNATURE_JSON_KEY] msidHexData];
        _authenticatorData = [[json msidStringObjectForKey:MSID_BROKER_PASSKEY_ASSERTION_AUTHENTICATOR_DATA_JSON_KEY] msidHexData];
        _credentialId = [[json msidStringObjectForKey:MSID_BROKER_PASSKEY_ASSERTION_CREDENTIAL_ID_JSON_KEY] msidHexData];
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];

    json[MSID_BROKER_PASSKEY_ASSERTION_SIGNATURE_JSON_KEY] = [self.signature msidHexString];
    json[MSID_BROKER_PASSKEY_ASSERTION_AUTHENTICATOR_DATA_JSON_KEY] = [self.authenticatorData msidHexString];
    json[MSID_BROKER_PASSKEY_ASSERTION_CREDENTIAL_ID_JSON_KEY] = [self.credentialId msidHexString];

    return json;
}

@end

#endif
