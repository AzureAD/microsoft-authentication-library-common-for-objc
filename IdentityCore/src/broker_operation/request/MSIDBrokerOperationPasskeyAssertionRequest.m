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


#import "MSIDBrokerOperationPasskeyAssertionRequest.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDConstants.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"

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
        _fidoChallenge = [json msidStringObjectForKey:MSID_BROKER_FIDO_CHALLENGE];
        if ([NSString msidIsStringNilOrBlank:_fidoChallenge])
        {
            // fidoChallenge is not needed, can be removed
        }
        
        _clientDataHash = [[json msidStringObjectForKey:@"clientDataHash"] msidHexData];
        _relyingPartyId = [json msidStringObjectForKey:@"relyingPartyId"];
        _keyId = [[json msidStringObjectForKey:@"keyId"] msidHexData];
        _userHandle = [[json msidStringObjectForKey:@"userHandle"] dataUsingEncoding:NSUTF8StringEncoding];
        
        _isRegistration = [json msidBoolObjectForKey:@"isRegistration"];
        
        _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json error:nil];
        if (_accountIdentifier && [NSString msidIsStringNilOrBlank:_accountIdentifier.homeAccountId])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Passkey Assertion Request - Account is provided, but no homeAccountId is provided from account identifier.", nil, nil, nil, nil, nil, YES);
            }
            
            return  nil;
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    json[@"clientDataHash"] = [self.clientDataHash msidHexString];
    json[@"relyingPartyId"] = self.relyingPartyId;
    json[@"keyId"] = [self.keyId msidHexString];
    json[@"userHandle"] = [[NSString alloc] initWithData:self.userHandle encoding:NSUTF8StringEncoding];
    
    json[@"isRegistration"] = [@(self.isRegistration) stringValue];
    
    return json;
}

@end
