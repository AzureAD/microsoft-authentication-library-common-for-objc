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


#import "MSIDPasskeyAssertion.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJsonSerializer.h"

NSString *const MSID_BROKER_PASSKEY_ASSERTION_SERVER_KEY_JSON_KEY = @"id";
NSString *const MSID_BROKER_PASSKEY_ASSERTION_CLIENT_DATA_JSON_KEY = @"clientDataJSON";
NSString *const MSID_BROKER_PASSKEY_ASSERTION_SIGNATURE_JSON_KEY = @"signature";
NSString *const MSID_BROKER_PASSKEY_ASSERTION_AUTHENTICATOR_DATA_JSON_KEY = @"authenticatorData";
NSString *const MSID_BROKER_PASSKEY_ASSERTION_USER_HANDLE_JSON_KEY = @"userHandle";

@implementation MSIDPasskeyAssertion


- (instancetype)initWithUserHandle:(NSData *)userHandle
                    relyingPartyId:(NSString *)relyingPartyId
                          signature:(NSData *)signature
                    clientDataHash:(NSData *)clientDataHash
                 authenticatorData:(NSData *)authenticatorData
                      credentialId:(NSData *)credentialId
                 attestationObject:(NSData * _Nullable)attestationObject
{
    self = [super init];
    
    if (self)
    {
        _userHandle = userHandle;
        _relyingPartyId = relyingPartyId;
        _signature = signature;
        _clientDataHash = clientDataHash;
        _authenticatorData = authenticatorData;
        _credentialId = credentialId;
        
        _attestationObject = attestationObject;
    }
    
    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _userHandle = [[json msidStringObjectForKey:@"userHandle"] msidHexData];
        _relyingPartyId = [json msidStringObjectForKey:@"relyingPartyId"];
        _signature = [[json msidStringObjectForKey:@"signature"] msidHexData];
        _clientDataHash = [[json msidStringObjectForKey:@"clientDataHash"] msidHexData];
        _authenticatorData = [[json msidStringObjectForKey:@"authenticatorData"] msidHexData];
        _credentialId = [[json msidStringObjectForKey:@"credentialId"] msidHexData];
        
        _attestationObject = [[json msidStringObjectForKey:@"attestationObject"] msidHexData];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    
    json[@"userHandle"] = [self.userHandle msidHexString];
    json[@"relyingPartyId"] = self.relyingPartyId;
    json[@"signature"] = [self.signature msidHexString];
    json[@"clientDataHash"] = [self.clientDataHash msidHexString];
    json[@"authenticatorData"] = [self.authenticatorData msidHexString];
    json[@"credentialId"] = [self.credentialId msidHexString];
    
    json[@"attestationObject"] = [self.attestationObject msidHexString];
    
    return json;
}

@end
