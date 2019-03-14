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

#import "MSIDAutomationAccountsResult.h"

@implementation MSIDAutomationAccountsResult

- (instancetype)initWithAction:(NSString *)actionId
                      accounts:(NSArray<MSIDAutomationUserInformation *> *)accounts
                additionalInfo:(nullable NSDictionary *)additionalInfo
{
    self = [super initWithAction:actionId success:YES additionalInfo:additionalInfo];

    if (self)
    {
        _accounts = accounts;
    }

    return self;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        NSMutableArray *results = [NSMutableArray new];

        for (NSDictionary *accountDict in json[@"accounts"])
        {
            MSIDAutomationUserInformation *userInfo = [[MSIDAutomationUserInformation alloc] initWithJSONDictionary:accountDict error:nil];
            [results addObject:userInfo];
        }

        _accounts = results;
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];

    NSMutableArray *accountsJSON = [NSMutableArray new];

    for (MSIDAutomationUserInformation *account in self.accounts)
    {
        NSDictionary *accountJSON = [account jsonDictionary];
        [accountsJSON addObject:accountJSON];
    }

    json[@"accounts"] = accountsJSON;
    return json;
}

@end
