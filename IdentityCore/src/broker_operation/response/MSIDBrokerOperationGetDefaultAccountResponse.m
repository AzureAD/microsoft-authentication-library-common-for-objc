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

#import "MSIDAccount.h"
#import "MSIDBrokerOperationGetDefaultAccountResponse.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"

@implementation MSIDBrokerOperationGetDefaultAccountResponse

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.responseType];
}

+ (NSString *)responseType
{
    return MSID_JSON_TYPE_BROKER_OPERATION_GET_DEFAULT_ACCOUNT_RESPONSE;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError *__autoreleasing*)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        if (self.success)
        {
            NSError *accountDeserializationError = nil;
            _account = [[MSIDAccount alloc] initWithJSONDictionary:json error:&accountDeserializationError];
            
            // If account is nil but there was an actual deserialization error, fail the response
            if (!_account && accountDeserializationError)
            {
                MSID_LOG_WITH_CORR(MSIDLogLevelError, nil, @"Failed to deserialize default account with error: %@", accountDeserializationError);
                if (error) *error = accountDeserializationError;
                return nil;
            }
            
            // If account is nil but no error was set, it means there was no account data in the JSON,
            // which is a valid scenario (e.g., no default account exists). The response succeeds with nil account.
        }
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;

    if (self.success && self.account)
    {
        NSDictionary *accountJson = [self.account jsonDictionary];
        if (!accountJson)
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelError, nil, @"Failed to create json for %@ class, account json is nil.", self.class);
            return nil;
        }
        [json addEntriesFromDictionary:accountJson];
    }

    return json;
}

@end

#endif
