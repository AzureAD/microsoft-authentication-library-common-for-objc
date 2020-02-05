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

#import "MSIDAutomationOperationAccountResponseHandler.h"
#import "MSIDTestAutomationAccount.h"

@implementation MSIDAutomationOperationAccountResponseHandler

- (id)responseFromData:(NSData *)response
                 error:(NSError **)error
{
    NSArray *jsonArray = [super responseFromData:response error:error];
    if (!jsonArray || ![jsonArray isKindOfClass:[NSArray class]])
    {
        return nil;
    }
    
    NSMutableDictionary *homeObjectIdDict = [NSMutableDictionary new];
    
    /*
     TODO: this class and handler is only needed because lab doesn't return homeObjectId yet, resulting in these hacks.
     It will be removed once homeObjectid is returned from lab
     */
    for (MSIDTestAutomationAccount *account in jsonArray)
    {
        if (account.isHomeAccount)
        {
            homeObjectIdDict[account.upn] = account.objectId;
        }
        else if (!account.homeObjectId)
        {
            [account setValue:homeObjectIdDict[account.upn] forKey:@"homeObjectId"];
            NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", account.homeObjectId, account.homeTenantId];
            [account setValue:homeAccountId forKey:@"homeAccountId"];
        }
    }
    
    return jsonArray;
}

@end
