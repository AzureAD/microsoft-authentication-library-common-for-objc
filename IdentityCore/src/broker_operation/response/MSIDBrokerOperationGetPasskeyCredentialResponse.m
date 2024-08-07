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

#import "MSIDBrokerOperationGetPasskeyCredentialResponse.h"
#import "MSIDPasskeyCredential.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"

@implementation MSIDBrokerOperationGetPasskeyCredentialResponse

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.responseType];
}

+ (NSString *)responseType
{
    return MSID_JSON_TYPE_BROKER_OPERATION_PASSKEY_CREDENTIAL_RESPONSE;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError *__autoreleasing*)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        if (self.success)
        {
            _passkeyCredential =[[MSIDPasskeyCredential alloc] initWithJSONDictionary:json error:error];
            if (!_passkeyCredential)
            {
                if (error)
                {
                    MSID_LOG_WITH_CORR(MSIDLogLevelError, nil, @"Failed to deserialize passkey credential with error: %@", *error);
                }
                else
                {
                    MSID_LOG_WITH_CORR(MSIDLogLevelError, nil, @"Failed to deserialize passkey credential.");
                }
                
                return nil;
            }
        }
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;

    if (self.success)
    {
        NSDictionary *passkeyCredentialJson = [self.passkeyCredential jsonDictionary];
        if (!passkeyCredentialJson)
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelError, nil, @"Failed to create json for %@ class, passkeyCredential json is nil.", self.class);
            return nil;
        }
        [json addEntriesFromDictionary:passkeyCredentialJson];
    }

    return json;
}

@end

#endif
