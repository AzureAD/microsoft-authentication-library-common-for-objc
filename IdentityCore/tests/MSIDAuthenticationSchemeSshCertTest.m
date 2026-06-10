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


#import <XCTest/XCTest.h>
#import "MSIDAuthenticationSchemeSshCert.h"

@interface MSIDAuthenticationSchemeSshCertTest : XCTestCase

@end

@implementation MSIDAuthenticationSchemeSshCertTest

- (void)test_InitWithCorrectParams_shouldReturnCompleteScheme
{
    MSIDAuthenticationSchemeSshCert *scheme = [[MSIDAuthenticationSchemeSshCert alloc] initWithSchemeParameters:[self prepareSshCertSchemeParameter]];
    [self test_assertDefaultAttributesInScheme:scheme];
}

- (void)test_InitWithInCorrectTokenType_shouldReturnNil
{
    MSIDAuthenticationSchemeSshCert *scheme = [[MSIDAuthenticationSchemeSshCert alloc] initWithSchemeParameters:[self prepareSshCertSchemeParameter_incorrectTokenType]];
    XCTAssertNil(scheme);
}


- (void)test_InitWithMissingTokenType_shouldReturnNil
{
    NSDictionary *json = [self prepareSshCertSchemeParameter_missingTokenType];
    NSError *error = nil;
    MSIDAuthenticationSchemeSshCert *scheme = [[MSIDAuthenticationSchemeSshCert alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNil(scheme);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)test_InitWithMissingReqConf_shouldReturnNil
{
    MSIDAuthenticationSchemeSshCert *scheme = [[MSIDAuthenticationSchemeSshCert alloc] initWithSchemeParameters:[self prepareSshCertSchemeParameter_missingRequestConf]];
    XCTAssertNil(scheme);
}

- (void)test_InitWithMissingKeyId_shouldReturnNil
{
    NSDictionary *json = [self prepareSshCertSchemeParameter_missingKeyId];
    NSError *error = nil;
    MSIDAuthenticationSchemeSshCert *scheme = [[MSIDAuthenticationSchemeSshCert alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNil(scheme);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (NSDictionary *)prepareSshCertSchemeParameter
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"ssh-cert" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"key_id_value" forKey:MSID_OAUTH2_SSH_CERT_KEY_ID];
    NSString *modulus = @"2tNr73xwcj6lH7bqRZrFzgSLj7OeLfbn8";
    NSString *exponent = @"AQAB";
    [params setObject:[NSString stringWithFormat:@"{\"kty\":\"RSA\", \"n\":\" + %@ + \", \"e\":\" + %@ + \"}", modulus, exponent] forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (NSDictionary *)prepareSshCertSchemeParameter_incorrectTokenType
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"ssh_cert" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"key_id_value" forKey:MSID_OAUTH2_SSH_CERT_KEY_ID];
    NSString *modulus = @"2tNr73xwcj6lH7bqRZrFzgSLj7OeLfbn8";
    NSString *exponent = @"AQAB";
    [params setObject:[NSString stringWithFormat:@"{\"kty\":\"RSA\", \"n\":\" + %@ + \", \"e\":\" + %@ + \"}", modulus, exponent] forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (NSDictionary *)prepareSshCertSchemeParameter_missingRequestConf
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"ssh-cert" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"key_id_value" forKey:MSID_OAUTH2_SSH_CERT_KEY_ID];
    NSString *modulus = @"2tNr73xwcj6lH7bqRZrFzgSLj7OeLfbn8";
    NSString *exponent = @"AQAB";
    [params setObject:[NSString stringWithFormat:@"{\"kty\":\"RSA\", \"n\":\" + %@ + \", \"e\":\" + %@ + \"}", modulus, exponent] forKey:@"req_cnf_1"];
    return params;
}

- (NSDictionary *)prepareSshCertSchemeParameter_missingTokenType
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"ssh-cert" forKey:@"token_type1"];
    [params setObject:@"key_id_value" forKey:MSID_OAUTH2_SSH_CERT_KEY_ID];
    NSString *modulus = @"2tNr73xwcj6lH7bqRZrFzgSLj7OeLfbn8";
    NSString *exponent = @"AQAB";
    [params setObject:[NSString stringWithFormat:@"{\"kty\":\"RSA\", \"n\":\" + %@ + \", \"e\":\" + %@ + \"}", modulus, exponent] forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (NSDictionary *)prepareSshCertSchemeParameter_missingKeyId
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"ssh-cert" forKey:@"token_type"];
    [params setObject:@"key_id_value" forKey:@"key_id_1"];
    NSString *modulus = @"2tNr73xwcj6lH7bqRZrFzgSLj7OeLfbn8";
    NSString *exponent = @"AQAB";
    [params setObject:[NSString stringWithFormat:@"{\"kty\":\"RSA\", \"n\":\" + %@ + \", \"e\":\" + %@ + \"}", modulus, exponent] forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (void)test_assertDefaultAttributesInScheme:(MSIDAuthenticationSchemeSshCert *)scheme
{
    XCTAssertNotNil([scheme valueForKey:MSID_OAUTH2_SSH_CERT_KEY_ID]);
    XCTAssertNotNil([scheme valueForKey:MSID_OAUTH2_REQUEST_CONFIRMATION]);
    XCTAssertEqual(scheme.authScheme, MSIDAuthSchemeSshCert);
    XCTAssertEqual(scheme.credentialType, MSIDAccessTokenWithAuthSchemeType);
    XCTAssertEqual(scheme.tokenType, MSID_OAUTH2_SSH_CERT);
}

@end
