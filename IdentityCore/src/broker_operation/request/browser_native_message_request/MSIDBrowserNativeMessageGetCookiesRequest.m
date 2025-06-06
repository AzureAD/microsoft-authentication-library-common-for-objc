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
#import "MSIDJsonSerializableFactory.h"

NSString *const MSID_BROWSER_NATIVE_MESSAGE_GET_COOKIES_REQUEST_URI_KEY = @"uri";

@implementation MSIDBrowserNativeMessageGetCookiesRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
}

+ (NSString *)operation
{
    return @"GetCookies";
}

- (NSString *)description
{
    __auto_type parentDescription = [super description];

    return [NSString stringWithFormat:@"%@ uri host: %@", parentDescription, self.uriHost];
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    self = [super initWithJSONDictionary:json error:error];
    if (!self) return nil;
    
    if (![json msidAssertType:NSString.class ofKey:MSID_BROWSER_NATIVE_MESSAGE_GET_COOKIES_REQUEST_URI_KEY required:YES error:error]) return nil;
    _uri = json[MSID_BROWSER_NATIVE_MESSAGE_GET_COOKIES_REQUEST_URI_KEY];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    @throw MSIDException(MSIDGenericException, @"Not implemented.", nil);
}

#pragma mark - Private

- (NSString *)uriHost
{
    if (!self.uri) return nil;
    
    NSURL *url = [[NSURL alloc] initWithString:self.uri];
    
    return url.host;
}

@end
