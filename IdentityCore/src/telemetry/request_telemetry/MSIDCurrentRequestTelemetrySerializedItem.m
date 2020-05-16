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

#import "MSIDCurrentRequestTelemetrySerializedItem.h"

@interface MSIDCurrentRequestTelemetrySerializedItem()

@property (nonatomic) NSNumber *schemaVersion;
@property (nonatomic) NSArray<NSObject *> *defaultFields;
@property (nonatomic) NSArray<NSObject *> *platformFields;

@end

@implementation MSIDCurrentRequestTelemetrySerializedItem

- (instancetype)initWithSchemaVersion:(NSNumber *)schemaVersion defaultFields:(NSArray *)defaultFields platformFields:(NSArray *)platformFields
{
    self = [super init];
    if (self)
    {
        _schemaVersion = schemaVersion;
        _defaultFields = defaultFields;
        _platformFields = platformFields;
    }
    return self;
}

// Builds current telemetry string using default serialization of each set of fields
// specified in the current telemetry string schema
- (NSString *)serialize
{
    NSString *telemetryString = [NSString stringWithFormat:@"%@|%@|%@", self.schemaVersion, [self serializeFields: self.defaultFields], [self serializeFields: self.platformFields]];
    
    if ([telemetryString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 4000)
    {
        return nil;
    }
    
    return telemetryString;
}

#pragma mark - Helper

- (NSString *)serializeFields:(NSArray *)fields
{
    if (fields)
    {
        return [fields componentsJoinedByString:@","];
    }
    else
    {
        return @"";
    }
}

@end
