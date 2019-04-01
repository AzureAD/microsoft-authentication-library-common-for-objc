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

@interface MSIDTestNSStringHelperMethods : XCTestCase

@end

@implementation MSIDTestNSStringHelperMethods

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMsidIsStringNilOrBlan_whenNil_shouldReturnTrue
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:nil], "Should return true for nil.");
}

- (void)testMsidIsStringNilOrBlank_whenNSNull_shouldReturnTrue
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:(NSString *)[NSNull null]]);
}

- (void)testMsidIsStringNilOrBlank_whenSpace_shouldReturnTrue
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@" "], "Should return true for nil.");
}

- (void)testMsidIsStringNilOrBlank_whenTab_shouldReturnTrue
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@"\t"], "Should return true for nil.");
}

- (void)testMsidIsStringNilOrBlank_whenEnter_shouldReturnTrue
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@"\r"], "Should return true for nil.");
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@"\n"], "Should return true for nil.");
}

- (void)testMsidIsStringNilOrBlank_whenMixedBlanks_shouldReturnTrue
{
    XCTAssertTrue([NSString msidIsStringNilOrBlank:@" \r\n\t  \t\r\n"], "Should return true for nil.");
}

- (void)testMsidIsStringNilOrBlank_whenNonEmpty_shouldReturnFalse
{
    //Prefix by white space:
    NSString* str = @"  text";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @" \r\n\t  \t\r\n text";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);

    //Suffix with white space:
    str = @"text  ";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @"text \r\n\t  \t\r\n";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    
    //Surrounded by white space:
    str = @"text  ";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
    str = @" \r\n\t text  \t\r\n";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);

    //No white space:
    str = @"t";
    XCTAssertFalse([NSString msidIsStringNilOrBlank:str], "Not an empty string %@", str);
}

- (void)testMsidTrimmedString
{
    XCTAssertEqualObjects([@" \t\r\n  test" msidTrimmedString], @"test");
    XCTAssertEqualObjects([@"test  \t\r\n  " msidTrimmedString], @"test");
    XCTAssertEqualObjects([@"test  \t\r\n  test" msidTrimmedString], @"test  \t\r\n  test");
    XCTAssertEqualObjects([@"  \t\r\n  test  \t\r\n  test  \t\r\n  " msidTrimmedString], @"test  \t\r\n  test");
}

#define VERIFY_BASE64(_ORIGINAL, _EXPECTED) { \
    NSString* encoded = [_ORIGINAL msidBase64UrlEncode]; \
    NSString* decoded = [_EXPECTED msidBase64UrlDecode]; \
    XCTAssertEqualObjects(encoded, _EXPECTED); \
    XCTAssertEqualObjects(decoded, _ORIGINAL); \
}

- (void)testMsidBase64UrlEncode_whenEmpty_shouldReturnEmptyString
{
    NSString *encodeEmpty = [@"" msidBase64UrlEncode];
    XCTAssertEqualObjects(encodeEmpty, @"");
}

- (void)testMsidBase64UrlDecode_whenEmpty_shouldReturnEmptyString
{
    NSString *decodeEmpty = [@"" msidBase64UrlDecode];
    XCTAssertEqualObjects(decodeEmpty, @"");
}

- (void)testMsidBase64UrlDecode_whenInvalid_shouldReturnNil
{
   //Decode invalid:
    XCTAssertFalse([@" " msidBase64UrlDecode].length, "Contains non-suppurted character < 128");
    XCTAssertNil([@" " msidBase64UrlDecode]);

    XCTAssertFalse([@"™" msidBase64UrlDecode].length, "Contains characters beyond 128");
    XCTAssertNil([@"™" msidBase64UrlDecode]);

    XCTAssertFalse([@"денят" msidBase64UrlDecode].length, "Contains unicode characters.");
    XCTAssertNil([@"денят" msidBase64UrlDecode]);
}

- (void)testMsidTrimmedString_whenStringWithWhiteSpace_shouldReturnTrimmedString
{
    NSString *string = @"   string   \n";
    XCTAssertEqualObjects(@"string", string.msidTrimmedString);
}

- (void)testMsidUWWWFormURLDecode_and_msidWWWFormURLEncode_whenHasSymbols_shouldEncodeDecode
{
    NSString *testString = @"Some interesting test/+-)(*&^%$#@!~|";
    NSString *encoded = [testString msidWWWFormURLEncode];
    
    XCTAssertEqualObjects(encoded, @"Some+interesting+test%2F%2B-%29%28%2A%26%5E%25%24%23%40%21~%7C");
    XCTAssertEqualObjects([encoded msidWWWFormURLDecode], testString);
}

- (void)testMsidWWWFormURLDecode_and_msidWWWFormURLEncode_whenHasNewLine_shouldEncodeDecode
{
    NSString* testString = @"test\r\ntest2";
    NSString* encoded = [testString msidWWWFormURLEncode];
    
    XCTAssertEqualObjects(encoded, @"test%0D%0Atest2");
    XCTAssertEqualObjects([encoded msidWWWFormURLDecode], testString);
}

- (void)testMsidWWWFormURLDecode_and_msidWWWFormURLEncode__whenHasSpace_shouldEncodeWithPlus
{
    NSString* testString = @"test test2";
    NSString* encoded = [testString msidWWWFormURLEncode];
    
    XCTAssertEqualObjects(encoded, @"test+test2");
    XCTAssertEqualObjects([encoded msidWWWFormURLDecode], testString);
}

- (void)testMsidWWWFormURLDecode_and_msidWWWFormURLEncode_whenHasIllegalChars_shouldEncodeAll
{
    NSString* testString = @"` # % ^ [ ] { } \\ | \" < > ! # $ & ' ( ) * + , / : ; = ? @ [ ] % | ^";
    NSString* encoded = [testString msidWWWFormURLEncode];
    
    XCTAssertEqualObjects(encoded, @"%60+%23+%25+%5E+%5B+%5D+%7B+%7D+%5C+%7C+%22+%3C+%3E+%21+%23+%24+%26+%27+%28+%29+%2A+%2B+%2C+%2F+%3A+%3B+%3D+%3F+%40+%5B+%5D+%25+%7C+%5E");
    XCTAssertEqualObjects([encoded msidWWWFormURLDecode], testString);
}

- (void)testMsidWWWFormURLDecode_and_msidWWWFormURLEncode_whenHasLegalChars_shouldNotEncode
{
    NSString* testString = @"test-test2-test3.test4";
    NSString* encoded = [testString msidWWWFormURLEncode];
    
    XCTAssertEqualObjects(encoded, @"test-test2-test3.test4");
    XCTAssertEqualObjects([encoded msidWWWFormURLDecode], testString);
}

- (void)testMsidWWWFormURLDecode_and_msidWWWFormURLEncode_whenHasMixedChars_shouldEncode
{
    NSString* testString = @"CODE: The app needs access to a service (\"https://*.test.com/\") that your organization \"test.onmicrosoft.com\" has not subscribed to or enabled.\r\nTrace ID: 111111-1111-1111-1111-111111111111\r\nCorrelation ID: 111111-1111-1111-1111-111111111111\r\nTimestamp: 2000-01-01 23:59:00Z";
    NSString* encoded = [testString msidWWWFormURLEncode];
    
    XCTAssertEqualObjects(encoded, @"CODE%3A+The+app+needs+access+to+a+service+%28%22https%3A%2F%2F%2A.test.com%2F%22%29+that+your+organization+%22test.onmicrosoft.com%22+has+not+subscribed+to+or+enabled.%0D%0ATrace+ID%3A+111111-1111-1111-1111-111111111111%0D%0ACorrelation+ID%3A+111111-1111-1111-1111-111111111111%0D%0ATimestamp%3A+2000-01-01+23%3A59%3A00Z");
    XCTAssertEqualObjects([encoded msidWWWFormURLDecode], testString);
}

- (void)testMsidIsEquivalentWithAnyAlias_whenContainedInAlias_shouldReturnYes
{
    NSArray *alias = @[@"authority1", @"authority2"];
    XCTAssertTrue([@"authority1" msidIsEquivalentWithAnyAlias:alias]);
}


- (void)testMsidIsEquivalentWithAnyAlias_whenNotContainedInAlias_shouldReturnNo
{
    NSArray *alias = @[@"authority1", @"authority2"];
    XCTAssertFalse([@"authorityX" msidIsEquivalentWithAnyAlias:alias]);
}

- (void)testMsidIsEquivalentWithAnyAlias_whenAliasNil_shouldReturnNo
{
    XCTAssertFalse([@"authorityX" msidIsEquivalentWithAnyAlias:nil]);
}

- (void)testMsidIsEquivalentWithAnyAlias_whenAliasEmpty_shouldReturnNo
{
    NSArray *alias = @[];
    XCTAssertFalse([@"authorityX" msidIsEquivalentWithAnyAlias:alias]);
}

- (void)testMsidHexStringFromData_whenJsonData_shouldReturnCorrectHexString
{
    NSString *string = @"{\"key\":\"val\"}";
    NSString *hexString = [NSString msidHexStringFromData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    
    XCTAssertEqualObjects(hexString, @"7b226b6579223a2276616c227d");
}

- (void)testMsidHexStringFromData_whenRandomStringData_shouldReturnCorrectHexString
{
    NSString *string = @"some string here";
    NSString *hexString = [NSString msidHexStringFromData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    
    XCTAssertEqualObjects(hexString, @"736f6d6520737472696e672068657265");
}

- (void)testMsidBase64UrlEncodedStringFromData
{
    NSString *string = @"   here is a string with padding  \n";
    NSString *base64urlEncodedString = [NSString msidBase64UrlEncodedStringFromData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    
    XCTAssertEqualObjects(base64urlEncodedString, @"ICAgaGVyZSBpcyBhIHN0cmluZyB3aXRoIHBhZGRpbmcgIAo");
    
    XCTAssertEqualObjects(base64urlEncodedString.msidBase64UrlDecode, string);
}

- (void)testmsidWWWFormURLEncodedStringFromDictionary_whenKeyValueStrings_shouldReturnUrlEncoded
{
    NSDictionary *dictionary = @{@"key": @"value"};
    NSString *result = [NSString msidWWWFormURLEncodedStringFromDictionary:dictionary];
    XCTAssertEqualObjects(result, @"key=value");
}

- (void)testmsidWWWFormURLEncodedStringFromDictionary_whenKeyStringValueUUID_shouldReturnUrlEncodedStr
{
    NSDictionary *dictionary = @{@"key": [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"]};
    NSString *result = [NSString msidWWWFormURLEncodedStringFromDictionary:dictionary];
    XCTAssertEqualObjects(result, @"key=E621E1F8-C36C-495A-93FC-0C247A3E6E5F");
}

- (void)testmsidWWWFormURLEncodedStringFromDictionary_whenKeyWithEmptyValue_shouldReturnUrlEncodedStri
{
    NSDictionary *dictionary = @{@"key":@""};
    NSString *result = [NSString msidWWWFormURLEncodedStringFromDictionary:dictionary];
    XCTAssertEqualObjects(result, @"key");
}

- (void)testmsidJson_whenNotJson_shouldReturnNil
{
    NSString *jsonString = @"{\"-not\":a json&*";
    XCTAssertNil(jsonString.msidJson);
}

- (void)testmsidJson_whenEmpty_shouldReturnNil
{
    NSString *jsonString = @"";
    XCTAssertNil(jsonString.msidJson);
}

- (void)testmsidJson_whenProperJson_shouldReturnDictionary
{
    NSString *jsonString = @"{\"json_key\":\"value\"}";
    NSDictionary *json = jsonString.msidJson;
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(json[@"json_key"], @"value");
}

- (void)testMsidScopeFromResource_whenResourceIsNil_shouldReturnNil
{
    XCTAssertNil([NSString msidScopeFromResource:nil]);
}

- (void)testMsidScopeFromResource_whenResourceIsNotNil_shouldAppendScopeSuffixWithSlash
{
    XCTAssertEqualObjects([NSString msidScopeFromResource:@"https://contoso.com"], @"https://contoso.com/.default");
}

- (void)testMsidScopeFromResource_whenResourceContainsSlashAtEnd_shouldAppendScopeSuffixWithSlash
{
    XCTAssertEqualObjects([NSString msidScopeFromResource:@"https://contoso.com/"], @"https://contoso.com//.default");
}

- (void)testMsidSecretLoggingHash_shouldReturnFirst8LettersOfPasswordHash
{
    __auto_type hash = [@"some password" msidSecretLoggingHash];
    
    XCTAssertEqualObjects(@"e62e1269", hash);
}

@end
