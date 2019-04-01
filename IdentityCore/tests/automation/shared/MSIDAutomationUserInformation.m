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

#import "MSIDAutomationUserInformation.h"

@implementation MSIDAutomationUserInformation

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[@"object_id"] = self.objectId;
    json[@"tenant_id"] = self.tenantId;
    json[@"given_name"] = self.givenName;
    json[@"family_name"] = self.familyName;
    json[@"username"] = self.username;
    json[@"home_account_id"] = self.homeAccountId;
    json[@"local_account_id"] = self.localAccountId;
    json[@"home_object_id"] = self.homeObjectId;
    json[@"home_tenant_id"] = self.homeTenantId;
    json[@"environment"] = self.environment;
    json[@"legacyAccountId"] = self.legacyAccountId;
    return json;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super init];

    if (self)
    {
        _objectId = json[@"object_id"];
        _tenantId = json[@"tenant_id"];
        _givenName = json[@"given_name"];
        _familyName = json[@"family_name"];
        _username = json[@"username"];
        _homeAccountId = json[@"home_account_id"];
        _localAccountId = json[@"local_account_id"];
        _homeObjectId = json[@"home_object_id"];
        _homeTenantId = json[@"home_tenant_id"];
        _environment = json[@"environment"];
        _legacyAccountId = json[@"legacyAccountId"];
    }

    return self;
}

@end
