//
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


#import "MSIDBrowserNativeMessageGetCookiesRequest.h"

@implementation MSIDBrowserNativeMessageGetCookiesRequest

+ (NSString *)method
{
    return @"GetCookies";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [self init];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:@"uri" required:YES error:error]) return nil;
        _uri = json[@"uri"];
        
        if (![json msidAssertType:NSString.class ofKey:@"sender" required:YES error:error]) return nil;
        _sender = json[@"sender"];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    
    if ([NSString msidIsStringNilOrBlank:self.uri]) return nil;
    json[@"uri"] = self.uri;
    
    if ([NSString msidIsStringNilOrBlank:self.sender]) return nil;
    json[@"sender"] = self.sender;
    
    return json;
}

@end
