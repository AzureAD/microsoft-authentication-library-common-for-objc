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

#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAccessToken.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDJsonSerializableFactory.h"

@implementation MSIDBrokerOperationTokenResponse

+ (void)load
{
    if (@available(iOS 13.0, *))
    {
        [MSIDJsonSerializableFactory registerClass:self forClassType:self.responseType];
    }
}

+ (NSString *)responseType
{
    return MSID_JSON_TYPE_BROKER_OPERATION_TOKEN_RESPONSE;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (self.success)
        {
            // TODO: support other response types.
            _tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:error];
            if (!_tokenResponse) return nil;
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
        NSDictionary *responseJson = [_tokenResponse jsonDictionary];
        if (responseJson) [json addEntriesFromDictionary:responseJson];
    }
    
    return json;
}

@end
