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
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDKeyedArchiverSerializerTests : XCTestCase

@end

@implementation MSIDKeyedArchiverSerializerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_whenSerializeToken_shouldReturnSameTokenOnDeserialize
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    MSIDAccessToken *expectedToken = [MSIDAccessToken new];
    [expectedToken setValue:@"access token value" forKey:@"accessTolen"];
    [expectedToken setValue:@"id token value" forKey:@"idToken"];
    [expectedToken setValue:[NSDate new] forKey:@"expiresOn"];
    [expectedToken setValue:@"familyId value" forKey:@"familyId"];
    
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    
    NSError *error = nil;
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(clientInfo);
    
    [expectedToken setValue:clientInfo forKey:@"clientInfo"];
    [expectedToken setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    [expectedToken setValue:@"some resource" forKey:@"resource"];
    [expectedToken setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    [expectedToken setValue:@"some clientId" forKey:@"clientId"];
    [expectedToken setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @2]] forKey:@"scopes"];
    
    NSData *data = [serializer serialize:expectedToken];
    MSIDAccessToken *resultToken = [serializer deserialize:data];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultToken, expectedToken);
}

- (void)testSerialize_whenTokenNil_shouldReturnNil
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    
    NSData *data = [serializer serialize:nil];
    
    XCTAssertNil(data);
}

- (void)testSerialize_whenTokenWithDefaultProperties_shouldReturnNotNilData
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    
    NSData *data = [serializer serialize:[MSIDAccessToken new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserialize_whenDataNilNil_shouldReturnNil
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    
    MSIDAccessToken *token = [serializer deserialize:nil];
    
    XCTAssertNil(token);
}

- (void)testDeserialize_whenDataInvalid_shouldReturnNil
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDAccessToken *token = [serializer deserialize:data];
    
    XCTAssertNil(token);
}

@end
