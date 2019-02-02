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

#import "MSIDAutomationTestResult.h"

@implementation MSIDAutomationTestResult

- (instancetype)initWithAction:(NSString *)actionId
                       success:(BOOL)success
                additionalInfo:(NSDictionary *)additionalInfo
{
    self = [super init];

    if (self)
    {
        _actionId = actionId;
        _success = success;
        _additionalInfo = additionalInfo;
    }
    return self;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    self = [super init];

    if (self)
    {
        _actionId = json[@"action_id"];
        _success = [json[@"success"] boolValue];
        _actionCount = [json[@"action_count"] integerValue];
        _additionalInfo = json;
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *jsonResultDict = [NSMutableDictionary new];
    jsonResultDict[@"action_id"] = _actionId;
    jsonResultDict[@"success"] = @(_success);
    jsonResultDict[@"action_count"] = @(_actionCount);

    if (_additionalInfo)
    {
        [jsonResultDict addEntriesFromDictionary:_additionalInfo];
    }

    return jsonResultDict;
}

@end
