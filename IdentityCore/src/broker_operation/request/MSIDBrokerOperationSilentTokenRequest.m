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

#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "MSIDConfiguration+MSIDJsonSerializable.h"
#import "MSIDAccountIdentifier+MSIDJsonSerializable.h"
#import "MSIDBrokerOperationRequestFactory.h"

@implementation MSIDBrokerOperationSilentTokenRequest

+ (void)load
{
    [MSIDBrokerOperationRequestFactory registerOperationRequestClass:self operation:self.operation];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return @"acquire_token_silent";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (![json msidAssertType:NSDictionary.class ofField:@"request_parameters" context:nil errorCode:MSIDErrorInvalidInternalParameter error:error]) return nil;
        NSDictionary *requestParameters = json[@"request_parameters"];
        
        _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:requestParameters error:error];
        if (!_accountIdentifier) return nil;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSMutableDictionary *requestParametersJson = [NSMutableDictionary new];
    
    NSDictionary *accountIdentifierJson = [self.accountIdentifier jsonDictionary];
    if (accountIdentifierJson) [requestParametersJson addEntriesFromDictionary:accountIdentifierJson];
    
    json[@"request_parameters"] = requestParametersJson;
    
    return json;
}

@end
