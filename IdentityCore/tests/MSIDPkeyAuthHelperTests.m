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
#import "MSIDPkeyAuthHelper.h"
#import <Security/Security.h>
#import <objc/runtime.h>
#import "MSIDWorkPlaceJoinUtil.h"
#import "NSData+MSIDTestUtil.h"
#import "MSIDRegistrationInformationMock.h"
#import "NSDate+MSIDTestUtil.h"

static MSIDRegistrationInformation *s_registrationInformationToReturn;

@interface MSIDPkeyAuthHelperTests : XCTestCase

@end

@implementation MSIDPkeyAuthHelperTests

- (void)setUp
{
    [self swizzleMethod:@selector(getRegistrationInformation:urlChallenge:)
                inClass:[MSIDWorkPlaceJoinUtil class]
             withMethod:@selector(getRegistrationInformationMock:urlChallenge:)
              fromClass:[self class]
     ];
    
    [NSDate mockCurrentDate:[[NSDate alloc] initWithTimeIntervalSince1970:5]];
}

- (void)tearDown
{
    [self swizzleMethod:@selector(getRegistrationInformation:urlChallenge:)
                inClass:[MSIDWorkPlaceJoinUtil class]
             withMethod:@selector(getRegistrationInformationMock:urlChallenge:)
              fromClass:[self class]
     ];
    
    [NSDate reset];
}

#pragma mark - Tests

- (void)testCreateDeviceAuthResponse_whenDeviceIsWPJ_shouldCreateProperResponse
{
    if (@available(iOS 10.0, *))
    {
        __auto_type challengeData = @{@"Context": @"some context",
                                      @"Version": @"1.0",
                                      @"nonce": @"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q",
                                      @"CertAuthorities": @"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net"};
        __auto_type regInfo = [MSIDRegistrationInformationMock new];
        regInfo.isWorkPlaceJoinedFlag = YES;
        [regInfo setPrivateKey:[self privateKey]];
        [regInfo setCertificateIssuer:@"82dbaca4-3e81-46ca-9c73-0950c1eaca97"];
        s_registrationInformationToReturn = regInfo;
        __auto_type url = [[NSURL alloc] initWithString:@"https://someurl.com"];
        
        __auto_type response = [MSIDPkeyAuthHelper createDeviceAuthResponse:url challengeData:challengeData context:nil];
        
        __auto_type expectedResponse = @"PKeyAuth AuthToken=\"ewogICJhbGciIDogIlJTMjU2IiwKICAidHlwIiA6ICJKV1QiLAogICJ4NWMiIDogWwogICAgIlptRnJaU0JrWVhSaCIKICBdCn0.ewogICJhdWQiIDogImh0dHBzOlwvXC9zb21ldXJsLmNvbSIsCiAgIm5vbmNlIiA6ICJYTm1lNlpsbm5aZ0lTNGJNSFB6WTRSaWhrSEZxQ0g2czFoblJnanY4WTBRIiwKICAiaWF0IiA6ICI1Igp9.NI9E37170Ykse1oRZlBqkzCn-VLbde3HGi6MdQOFlnkIopSDlzeh00Fc2-YAVcKMPbmmbHZRpOppoZGTFItRSzOyiDQkpVaC_l89w1ip2OdarOffdc2SmGmFL80RqlsnWEvz7h1tC-Ziq5A1va58alL2hrPwdZe8fTGzQmo87MUz_gLwdf8GHbGqVqgE_csavbFrPo1iHu6qZiIcI8CBYzRpXOZsILDlvjBjtuxQ1cJDSBkmTg1TUemU8yrbxoB4wcTxvgmDbe8QCCCJwyxbo4Ww8leQd0D3cCrhRHihs6bHjI2y9z00vOj-4Qj0JC20hGUW9EdZFuB8vmvwsyT34g\", Context=\"some context\", Version=\"1.0\"";
        
        XCTAssertEqualObjects(expectedResponse, response);
    }
}

- (void)testCreateDeviceAuthResponse_whenDeviceIsWPJAndAuthServerUrlWihtQueryParams_shouldCreateProperResponse
{
    if (@available(iOS 10.0, *))
    {
        __auto_type challengeData = @{@"Context": @"some context",
                                      @"Version": @"1.0",
                                      @"nonce": @"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q",
                                      @"CertAuthorities": @"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net"};
        __auto_type regInfo = [MSIDRegistrationInformationMock new];
        regInfo.isWorkPlaceJoinedFlag = YES;
        [regInfo setPrivateKey:[self privateKey]];
        [regInfo setCertificateIssuer:@"82dbaca4-3e81-46ca-9c73-0950c1eaca97"];
        s_registrationInformationToReturn = regInfo;
        __auto_type url = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=testslice"];
        
        __auto_type response = [MSIDPkeyAuthHelper createDeviceAuthResponse:url challengeData:challengeData context:nil];
        
        __auto_type expectedResponse = @"PKeyAuth AuthToken=\"ewogICJhbGciIDogIlJTMjU2IiwKICAidHlwIiA6ICJKV1QiLAogICJ4NWMiIDogWwogICAgIlptRnJaU0JrWVhSaCIKICBdCn0.ewogICJhdWQiIDogImh0dHBzOlwvXC9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tXC9jb21tb25cL29hdXRoMlwvdjIuMFwvdG9rZW4iLAogICJub25jZSIgOiAiWE5tZTZabG5uWmdJUzRiTUhQelk0Umloa0hGcUNINnMxaG5SZ2p2OFkwUSIsCiAgImlhdCIgOiAiNSIKfQ.HMgqNP2ZkDFZC7u_jo4Vlc6lMozr1x05rCTyMaJwvCIQx6vO9bPjhJ2f-fXrd_W9syrAa4TNRQZELfQPm-3dCVzHBpRJzDrH-Z3S3zYE4egWBq59BwNsrSbtgevlyeusd6h9z-WLDOVMZN1n79v4K6sSux0WEwaxGPjU0haTIBZmqaT0NEsLADDdeAMJCLN9Exd4VFi4GeZ9jsTw3_bzHS_2I8lyj5r8lr4yHUpPdxw0rFvOacJepbPqd_vW7jKl2tSZRVDw9iWRA9CxWWgVp3eZrPUesx7oLnkAnp7mIfKuhI4bL3yxAkg1ouErYqlIhJUgK7jR1OPZOKhBXSV98Q\", Context=\"some context\", Version=\"1.0\"";
        
        XCTAssertEqualObjects(expectedResponse, response);
    }
}

- (void)testCreateDeviceAuthResponse_whenDeviceIsNotWPJ_shouldCreateProperResponse
{
    if (@available(iOS 10.0, *))
    {
        s_registrationInformationToReturn = nil;
        __auto_type challengeData = @{@"Context": @"some context",
                                      @"Version": @"1.0",
                                      @"nonce": @"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q",
                                      @"CertAuthorities": @"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net"};
        __auto_type url = [[NSURL alloc] initWithString:@"https://someurl.com"];
        
        __auto_type response = [MSIDPkeyAuthHelper createDeviceAuthResponse:url challengeData:challengeData context:nil];
        
        __auto_type expectedResponse = @"PKeyAuth  Context=\"some context\", Version=\"1.0\"";
        
        XCTAssertEqualObjects(expectedResponse, response);
    }
}

- (void)testCreateDeviceAuthResponse_whenCertDoesnotMatch_shouldCreateProperResponse
{
    if (@available(iOS 10.0, *))
    {
        __auto_type challengeData = @{@"Context": @"some context",
                                      @"Version": @"1.0",
                                      @"nonce": @"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q",
                                      @"CertAuthorities": @"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net"};
        __auto_type regInfo = [MSIDRegistrationInformationMock new];
        regInfo.isWorkPlaceJoinedFlag = YES;
        [regInfo setPrivateKey:[self privateKey]];
        [regInfo setCertificateIssuer:@"XXXXXX"];
        s_registrationInformationToReturn = regInfo;
        __auto_type url = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=testslice"];
        
        __auto_type response = [MSIDPkeyAuthHelper createDeviceAuthResponse:url challengeData:challengeData context:nil];
        
        __auto_type expectedResponse = @"PKeyAuth  Context=\"some context\", Version=\"1.0\"";
        
        XCTAssertEqualObjects(expectedResponse, response);
    }
}


#pragma mark - Private

- (SecKeyRef)privateKey
{
    __auto_type hexString = @"308204a3 02010002 82010100 b1dc0c48 cc3192e3 790f615c 7c50dac6 b25e30ff 26eddf8e 6db8eb67 44b0b35e ee71e8c8 14a4200f 0e9dee71 117bce26 31f6f5db 8b5f8ab0 a197cc8b 20661c87 e231f618 189f5e5e 26d6b90d 83c025fc 931b164c fd6ee3f8 91d0fb8a 795cccaa 6f24fccc 1052fc75 ae6a2558 4d7b93ab 63cdc3fa 357fa238 8e34684b 5146233e e50eba7b 89b61bc7 82bcaca0 b216568b d58ea7fb 1bc09bf7 c6cb31ed 72f51c1c aa69674c d307843e 31a41531 0ab1a091 927a0f7f 1022ef46 bf72143b 26f08a57 cc2afdb5 ac0bc7d0 753812f0 bd82a633 dc44e8a6 a80d55c1 56304748 89fce0db 2174ce94 a2f93607 b48fb6c7 3281f0d7 d85dbc8f 70dc8257 7d4eb7a8 e877bf33 02030100 01028201 000de5d4 ebe750c4 5a93fe18 ac82664b 0215b3f8 7e278b94 d96b4774 d587ef8a c4933b41 6648fe9e 26af0cb6 320d9caf fa1a1363 18b9a648 8f0ec16e d13c41de 5edbd4ed 96ea6da1 9117d5d5 75f1e294 d54ca564 33b5e5f1 585e0487 73459273 c7a991a9 5344bf47 4ce6c912 8bf8d9fc 2afb4c7b d0d45759 d4b37ff2 da57ca74 3c774541 2d9d5bdc 8eac55d3 5b80f31a d0d75df4 c1a80248 495b72fd 30705ab8 20e9fbcb e5bf06e0 10a68aab d986b76f d34c711a d07a45be 53d668ca 7851c135 f041ca8d 013b6e99 bf6681db 7cb8a7db 1581470e e0d74e90 9adb773b 604b38a7 45743b09 7c4ec4b2 73828383 d2f361d4 0ee5a002 827f3812 39a37f29 5f9afb72 79028181 00f34013 54f20db9 ea06e732 66d6da62 3997ddbc b861e3ca 36ff994f 8ee851bd aa90fe36 b212f0da d3f745b2 7621544b df498b1b 8c991fc6 90b133dc db148798 b6dc83d9 1d341115 4fd2397e 40b6e6e4 5def4585 3f4721de eabefcd1 6cd8b1d5 6ab8e0b0 054eee00 2a3d7046 9c30e544 ebb2095c 41b96997 f33a47ee d8cd882f e7028181 00bb2e8f cfd51f36 98cd7169 9012fe2d 9cde0518 abd13609 829a7c7c de23b34a aafb89fd 632a3c99 8ab0fabc 4d812fd0 091ac5b2 bb12455d b8c4ad0c fa616b02 4084bbbf c6b013a2 27d75f0f ef419e38 3e96561d 1295fd37 146001e0 c2d14a1e c7aa9755 3b61ca76 4acbb47d fdf46cf5 78c9c099 2ac9778a dff39a1c b54aec7c d5028181 00d0e070 b93cb0f4 b834fd4a 966c6052 804a1c29 f5da7914 276e0c63 f8bf1d91 d4697521 da7fd13a d7513a14 28c42df2 88e64a01 7a15f2e7 3b502ecc b383497c a5696dfe 7dc93bf2 24fccc49 d1a03d5c 541d2681 68f8d7e8 e782e0ed a49ddef6 f811913f 150fd5e7 665e238f 3e87ee17 e49c98d5 13caf715 77d2cffa 1549486c 79028180 377babc1 2d291d63 d9b1be5a a866935a a62cd88d 456c4111 677d72fd dd932d94 d50ea7ff 16ebf38f 3aba77ca 797a94ad be33cfb0 c7cfabe2 32da20b8 aedbab45 3892f65b 8ca1a535 2e0fcd87 5be9ec3e 110de17c 3add5dd0 3a4d1434 6b190f5a 9be453ad 506554ff 02b6b389 ed43c6d7 50e63800 88cb586c dda656d0 1e2f4f29 0281806e 1d67170c 6fbf6cd7 7a69a2e7 f3aa8ae0 10d353cd 1153dfc9 f689a6a3 20438a14 841615e3 aa5d5b00 b7bb61ea 8ec8ea02 1b2bf85c 03761e5c a5dc6d4f 97179b2a 386aaa02 b6c3ec3f 37d29d46 e8ba5082 008d7e92 b00eed5d 943552ef e5dde749 b1c0a549 149a8b09 170a128a fe503554 17214ae7 ac699b5f 21c06faa 6d22ce";
    
    __auto_type data = [NSData hexStringToData:hexString];
    
    NSDictionary *attributes = @{ (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA, (id)kSecAttrKeySizeInBits: @2048, (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate };
    
    SecKeyRef signingKey = NULL;
    if (@available(iOS 10.0, *))
    {
        signingKey = SecKeyCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)attributes, NULL);
    }
    
    return signingKey;
}

- (void)swizzleMethod:(SEL)defaultMethod
              inClass:(Class)class
           withMethod:(SEL)swizzledMethod
            fromClass:(Class)aNewClass
{
    Method originalMethod = class_getClassMethod(class, defaultMethod);
    Method mockMethod = class_getClassMethod(aNewClass, swizzledMethod);
    method_exchangeImplementations(originalMethod, mockMethod);
}

+ (MSIDRegistrationInformation *)getRegistrationInformationMock:(id<MSIDRequestContext>)context
                                                   urlChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    return s_registrationInformationToReturn;
}

@end
