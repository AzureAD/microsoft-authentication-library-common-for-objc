//
//  MSIDStringExtensionTests.m
//  IdentityCoreTests iOS
//
//  Created by Sergey Demchenko on 1/3/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSString+MSIDExtensions.h"

@interface MSIDStringExtensionTests : XCTestCase

@end

@implementation MSIDStringExtensionTests

- (void)setUp
{
}

- (void)tearDown
{
}

#pragma mark - Tests

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

@end
