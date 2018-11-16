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
#import "MSIDBrokerCryptoProvider.h"
#import "NSData+MSIDExtensions.h"

@interface MSIDBrokerCryptoProviderTests : XCTestCase

@end

@implementation MSIDBrokerCryptoProviderTests

- (void)testDecryptBrokerResponse_whenHashMissing_shouldReturnError
{
    NSData *encryptionKey = [@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDBrokerCryptoProvider *cryptoHelper = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:encryptionKey];

    NSDictionary *payload = @{@"msg_protocol_ver": @1,
                              @"response": @"response"
                              };

    NSError *error = nil;
    NSDictionary *result = [cryptoHelper decryptBrokerResponse:payload correlationId:nil error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerResponseHashMissing);
}

- (void)testDecryptBrokerResponse_whenResponseNotProperlyEncoded_shouldReturnError
{
    NSData *encryptionKey = [@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U" dataUsingEncoding:NSUTF8StringEncoding];
    MSIDBrokerCryptoProvider *cryptoHelper = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:encryptionKey];

    NSDictionary *payload = @{@"msg_protocol_ver": @1,
                              @"response": @",,,",
                              @"hash": @"hash"
                              };

    NSError *error = nil;
    NSDictionary *result = [cryptoHelper decryptBrokerResponse:payload correlationId:nil error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerCorruptedResponse);
}

- (void)testDecryptBrokerResponse_whenMismatchingHash_shouldReturnError
{
    NSData *encryptionKey = [NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"];
    MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:encryptionKey];

    NSString *v1EncryptedPayload = @"OxDgUethOjve95lfr1OIFjv9ExbhxTTESae11KZChY2SAsDBZCyRI87/HCutimLfIpvqWHJ7P6ygVGJlnr1yHZf4aguJ4zq1auczsXeTPPYoNVxHNGbbMJgAkjcnCI6SJG9JqXlS8IjVNFDTZvVswlLWzwsQLL5O36/gGM77eONyhMkRexN36wMMgSkrtTzov1OOn2od9ErutVTyBNZ+bNbAhzYQgNzkvbgERFdBMlDN7EIuFO4TMgizcYhbvaGY+jNb8Ktwbk0hXxKfMKm8HL332ub3RbRrW0BWPJACPtyzN3X9pnxncZHg8hZJzYh3";

    NSDictionary *payloadDict = @{@"msg_protocol_ver":@1,
                                  @"response": v1EncryptedPayload,
                                  @"hash": @"59130F051E9DFA85042A00CE65BD9B67A7BF7DC0783C5B17FA8C92393D3DE0B2"
                                  };

    NSError *error = nil;

    NSDictionary *decrypted = [cryptoProvider decryptBrokerResponse:payloadDict correlationId:nil error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(decrypted);
    XCTAssertEqual(error.code, MSIDErrorBrokerResponseHashMismatch);
}

- (void)testDecryptBrokerResponse_whenInvalidEncryptedData_shouldReturnResponseError
{
    NSData *encryptionKey = [NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"];
    MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:encryptionKey];

    NSString *v1EncryptedPayload = @"6y9Qi50PHeSBT7tk/Yi+AdHxlR2XH15ME8mN4S0shmgnh1fPn/7Sn9fVH+PQZ17aU27w3W6RfxLt1K66NpbFRgNj7O9ZMwMa6JAtsyuU5QKNFv019+3C20AJnhyZFIJ42W4E94N73g16/O1qMIemISsc+iZF7xN//CuJZeX8urU=";

    NSDictionary *payloadDict = @{@"msg_protocol_ver":@1,
                                  @"response": v1EncryptedPayload,
                                  @"hash": @"69130F051E9DFA85042A00CE65BD9B67A7BF7DC0783C5B17FA8C92393D3DE0B2"
                                  };

    NSError *error = nil;

    NSDictionary *decrypted = [cryptoProvider decryptBrokerResponse:payloadDict correlationId:nil error:&error];

    XCTAssertNotNil(error);
    XCTAssertNil(decrypted);
    XCTAssertEqual(error.code, MSIDErrorBrokerResponseDecryptionFailed);
}

- (void)testDecryptBrokerResponse_whenValidResponse_shouldReturnResponseDictionary
{
    NSData *encryptionKey = [NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"];
    MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:encryptionKey];

    NSString *v1EncryptedPayload = @"OxDgUethOjve95lfr1OIFjv9ExbhxTTESae11KZChY2SAsDBZCyRI87/HCutimLfIpvqWHJ7P6ygVGJlnr1yHZf4aguJ4zq1auczsXeTPPYoNVxHNGbbMJgAkjcnCI6SJG9JqXlS8IjVNFDTZvVswlLWzwsQLL5O36/gGM77eONyhMkRexN36wMMgSkrtTzov1OOn2od9ErutVTyBNZ+bNbAhzYQgNzkvbgERFdBMlDN7EIuFO4TMgizcYhbvaGY+jNb8Ktwbk0hXxKfMKm8HL332ub3RbRrW0BWPJACPtyzN3X9pnxncZHg8hZJzYh3";

    NSDictionary *payloadDict = @{@"msg_protocol_ver":@1,
                                  @"response": v1EncryptedPayload,
                                  @"hash": @"69130F051E9DFA85042A00CE65BD9B67A7BF7DC0783C5B17FA8C92393D3DE0B2"
                                  };

    NSError *error = nil;

    NSDictionary *decrypted = [cryptoProvider decryptBrokerResponse:payloadDict correlationId:nil error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(decrypted);

    NSString *expectedResult = @"VGhpcyBpcyB0aGUgc29uZyB0aGF0IGRvZXNuJ3QgZW5kLCB5ZXMgaXQgZ29lcyBvbiBhbmQgb24gbXkgZnJpZW5kLiBTb21lIHBlb3BsZSBzdGFydGVkIHNpbmdpbmcgaXQgbm90IGtub3dpbmcgd2hhdCBpdCB3YXMsIGFuZCB0aGV5J2xsIGNvbnRpbnVlIHNpbmdpbmcgaXQgZm9yZXZlciBqdXN0IGJlY2F1c2UuLi4";

    XCTAssertEqualObjects(decrypted, @{expectedResult:@""});
}

- (void)testDecryptData_whenV1Key_shouldReturnData
{
    NSData *encryptionKey = [NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"];
    MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:encryptionKey];

    NSString *v1EncryptedPayload = @"OxDgUethOjve95lfr1OIFjv9ExbhxTTESae11KZChY2SAsDBZCyRI87/HCutimLfIpvqWHJ7P6ygVGJlnr1yHZf4aguJ4zq1auczsXeTPPYoNVxHNGbbMJgAkjcnCI6SJG9JqXlS8IjVNFDTZvVswlLWzwsQLL5O36/gGM77eONyhMkRexN36wMMgSkrtTzov1OOn2od9ErutVTyBNZ+bNbAhzYQgNzkvbgERFdBMlDN7EIuFO4TMgizcYhbvaGY+jNb8Ktwbk0hXxKfMKm8HL332ub3RbRrW0BWPJACPtyzN3X9pnxncZHg8hZJzYh3";

    NSError *error = nil;

    NSData *decrypted = [cryptoProvider decryptData:[[NSData alloc] initWithBase64EncodedString:v1EncryptedPayload options:0] protocolVersion:1];

    XCTAssertNil(error);
    XCTAssertNotNil(decrypted);

    NSString* payload = @"VGhpcyBpcyB0aGUgc29uZyB0aGF0IGRvZXNuJ3QgZW5kLCB5ZXMgaXQgZ29lcyBvbiBhbmQgb24gbXkgZnJpZW5kLiBTb21lIHBlb3BsZSBzdGFydGVkIHNpbmdpbmcgaXQgbm90IGtub3dpbmcgd2hhdCBpdCB3YXMsIGFuZCB0aGV5J2xsIGNvbnRpbnVlIHNpbmdpbmcgaXQgZm9yZXZlciBqdXN0IGJlY2F1c2UuLi4";
    XCTAssertEqualObjects(decrypted, [payload dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testDecryptData_whenV2Key_shouldReturnData
{
    NSData *encryptionKey = [NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"];
    MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:encryptionKey];

    NSString *v2EncryptedPayload = @"OwkUbeZ63OlLI1xsNUXOJKmJgjhApcV6bEzFI6cdtE4UtsboGnJLjUtJRySO8ol97W431BdpwnuFD8tImkjUx++oNAMU483Q1xpuc5mCNVZcpDpnMoW2EC9oM5slGTPvvmDBxu3MHbLVVKWB616eKUdSKGOBnBUWDZp6QJJXpwEzwZuoycmmbQBF2SI1Ur5bluma8d23hANpV1c0qCGtPvEcLXWp7vNp5gkIsd6rGAkuuk31GJ3E8j+gfd8XymUEFc8g9ikx4JG0JnRwmRkzgVVKgszDPlPJrqlGlCZqa0SiF8V0pT3CqM6HURkqmCvK";

    NSData *decrypted = [cryptoProvider decryptData:[[NSData alloc] initWithBase64EncodedString:v2EncryptedPayload options:0] protocolVersion:2];

    XCTAssertNotNil(decrypted);

    NSString *payload = @"VGhpcyBpcyB0aGUgc29uZyB0aGF0IGRvZXNuJ3QgZW5kLCB5ZXMgaXQgZ29lcyBvbiBhbmQgb24gbXkgZnJpZW5kLiBTb21lIHBlb3BsZSBzdGFydGVkIHNpbmdpbmcgaXQgbm90IGtub3dpbmcgd2hhdCBpdCB3YXMsIGFuZCB0aGV5J2xsIGNvbnRpbnVlIHNpbmdpbmcgaXQgZm9yZXZlciBqdXN0IGJlY2F1c2UuLi4";
    XCTAssertEqualObjects(decrypted, [payload dataUsingEncoding:NSUTF8StringEncoding]);
}
@end
