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

#import <XCTest/XCTest.h>
#import "MSIDUrlRequestSerializer.h"

@interface MSIDUrlRequestSerializerTests : XCTestCase

@property (nonatomic) MSIDUrlRequestSerializer *urlRequestSerializer;

@end

@implementation MSIDUrlRequestSerializerTests

- (void)setUp
{
    [super setUp];
    
    self.urlRequestSerializer = [MSIDUrlRequestSerializer new];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testSerializeWithRequest_whenPostRequest_shouldEncodeParametersInBody
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"POST";;
    __auto_type expectedBody = [[parameters msidWWWFormURLEncode] dataUsingEncoding:NSUTF8StringEncoding];
    
    __auto_type newUrlRequest = [self.urlRequestSerializer serializeWithRequest:urlRequest parameters:parameters];
    
    XCTAssertEqualObjects(expectedBody, newUrlRequest.HTTPBody);
    XCTAssertEqualObjects(baseUrl, newUrlRequest.URL);
    __auto_type headers = newUrlRequest.allHTTPHeaderFields;
    XCTAssertEqualObjects(headers[@"Content-Type"], @"application/x-www-form-urlencoded");
}

- (void)testSerializeWithRequest_whenGetRequest_shouldEncodeParametersInUrl
{
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type parameters = @{@"p1" : @"v1", @"p2" : @"v2"};
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:baseUrl];
    urlRequest.HTTPMethod = @"GET";;
    
    __auto_type newUrlRequest = [self.urlRequestSerializer serializeWithRequest:urlRequest parameters:parameters];
    
    XCTAssertNil(newUrlRequest.HTTPBody);
    XCTAssertEqualObjects(@"https://fake.url?p2=v2&p1=v1", newUrlRequest.URL.absoluteString);
}

@end
