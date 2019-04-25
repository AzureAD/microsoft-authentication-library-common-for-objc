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

#import "MSIDIndividualClaimRequestAdditionalInfo.h"

static NSString *const kEssentialJsonParam = @"essential";
static NSString *const kValueJsonParam = @"value";
static NSString *const kValuesJsonParam = @"values";

@implementation MSIDIndividualClaimRequestAdditionalInfo

- (NSString *)description
{
    NSString *baseDescription = [super description];
    return [baseDescription stringByAppendingFormat:@"(essential=%@, value=%@, values=%@)", self.essential, self.value, self.values];
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        if (json[kEssentialJsonParam])
        {
            if (![json msidAssertType:NSNumber.class
                              ofField:kEssentialJsonParam
                              context:nil
                            errorCode:MSIDErrorInvalidDeveloperParameter
                                error:error])
            {
                return nil;
            }
            _essential = json[kEssentialJsonParam];
        }

        _value = json[kValueJsonParam];
        NSArray *values = json[kValuesJsonParam];
        
        if (values)
        {
            if (![values isKindOfClass:NSArray.class])
            {
                if (error) *error = MSIDCreateError(MSIDErrorDomain,
                                                    MSIDErrorInvalidDeveloperParameter,
                                                    @"values is not an NSArray.",
                                                    nil, nil, nil, nil, nil);
                
                MSID_LOG_ERROR(nil, @"Failed to init MSIDIndividualClaimRequestAdditionalInfo with json: values is not an NSArray.");
                return nil;
            }
            
            _values = values;
        }

        BOOL isJsonValid = _essential != nil || _value != nil || _values != nil;
        
        if (!isJsonValid)
        {
            if (error) *error = MSIDCreateError(MSIDErrorDomain,
                                                MSIDErrorInvalidDeveloperParameter,
                                                @"Failed to init claim additional info from json.",
                                                nil, nil, nil, nil, nil);
            
            MSID_LOG_ERROR(nil, @"Failed to init MSIDIndividualClaimRequestAdditionalInfo with json: json is invalid.");
            return nil;
        }
    }
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    NSNumber *essential = self.essential;
    if (essential) essential = [[NSNumber alloc] initWithBool:self.essential.boolValue];
    dictionary[kEssentialJsonParam] = essential;
    dictionary[kValueJsonParam] = self.value;
    dictionary[kValuesJsonParam] = self.values;
    
    return dictionary;
}

@end
