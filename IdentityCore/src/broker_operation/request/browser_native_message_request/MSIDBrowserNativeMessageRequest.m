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


#import "MSIDBrowserNativeMessageRequest.h"
#import "MSIDBrokerConstants.h"

NSString *const BROWSER_NATIVE_MESSAGE_SENDER_KEY = @"sender";
NSString *const BROWSER_NATIVE_MESSAGE_METHOD_KEY = @"method";


@implementation MSIDBrowserNativeMessageRequest

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:BROWSER_NATIVE_MESSAGE_SENDER_KEY required:YES error:error]) return nil;
        _sender = json[BROWSER_NATIVE_MESSAGE_SENDER_KEY];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    
    if ([NSString msidIsStringNilOrBlank:self.sender]) return nil;
    json[BROWSER_NATIVE_MESSAGE_SENDER_KEY] = self.sender;
    
    if ([NSString msidIsStringNilOrBlank:self.class.operation]) return nil;
    json[BROWSER_NATIVE_MESSAGE_METHOD_KEY] = self.class.operation;
    
    return json;
}

@end
