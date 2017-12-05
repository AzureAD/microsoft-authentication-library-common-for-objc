//
//  MSIDKeyedArchiverSerializerTests.m
//  IdentityCore
//
//  Created by Sergey Demchenko on 12/7/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDToken.h"

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
    MSIDKeyedArchiverSerializer *serializer = [MSIDKeyedArchiverSerializer new];
    
    MSIDToken *expectedToken = [MSIDToken new];
    [expectedToken setValue:@"access token value" forKey:@"token"];
    [expectedToken setValue:@"id token value" forKey:@"idToken"];
    [expectedToken setValue:[NSDate new] forKey:@"expiresOn"];
    [expectedToken setValue:@"familyId value" forKey:@"familyId"];
    [expectedToken setValue:@{@"key" : @"value"} forKey:@"clientInfo"];
    [expectedToken setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    
    NSData *data = [serializer serialize:expectedToken];
    MSIDToken *resultToken = [serializer deserialize:data];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultToken, expectedToken);
}

@end
