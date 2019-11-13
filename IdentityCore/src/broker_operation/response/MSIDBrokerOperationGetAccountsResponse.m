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

#import "MSIDBrokerOperationGetAccountsResponse.h"
#import "MSIDAccount.h"

@implementation MSIDBrokerOperationGetAccountsResponse

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (![json msidAssertType:NSArray.class ofKey:@"accounts" required:YES error:error])
        {
            return nil;
        }
        NSArray *accountsJson = json[@"accounts"];
        
        NSMutableArray *accounts = [NSMutableArray new];
        for (NSDictionary *accountJson in accountsJson)
        {
            if (![accountJson isKindOfClass:NSDictionary.class])
            {
                continue;
            }
            
            NSError *localError;
            MSIDAccount *account = [[MSIDAccount alloc] initWithJSONDictionary:accountJson error:&localError];
            if (!account)
            {
                // We log the error and continue to parse other accounts data
                MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"MSIDBrokerOperationGetAccountsResponse - could not parse accounts with error domain (%@) + error code (%ld).", localError.domain, (long)localError.code);
                continue;
            }
            
            [accounts addObject:account];
        }
        
        self.accounts = accounts;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    
    NSMutableArray *accountsJson = [NSMutableArray new];
    
    for (MSIDAccount *account in self.accounts)
    {
        NSDictionary *accountJson = [account jsonDictionary];
        if (accountJson) [accountsJson addObject:accountJson];
    }
    
    json[@"accounts"] = accountsJson;
    
    return json;
}

@end
