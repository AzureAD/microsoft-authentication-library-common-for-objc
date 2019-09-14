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

#import "MSIDAccountIdentifier+MSIDJsonSerializable.h"

@implementation MSIDAccountIdentifier (MSIDJsonSerializable)

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (![json msidAssertType:NSString.class
                      ofField:@"username"
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *displayableId = json[@"username"];
    
    if (![json msidAssertType:NSString.class
                      ofField:@"home_account_id"
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *homeAccountId = json[@"home_account_id"];
    
    return [self initWithDisplayableId:displayableId homeAccountId:homeAccountId];
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[@"username"] = self.displayableId;
    json[@"home_account_id"] = self.homeAccountId;
    
    return json;
}

@end
