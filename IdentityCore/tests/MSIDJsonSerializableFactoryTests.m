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
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializable.h"

@interface MSIDJsonSerializableMock : NSObject<MSIDJsonSerializable>

@property (nonatomic) NSDictionary *receivedJson;

@end

@implementation MSIDJsonSerializableMock

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        _receivedJson = json;
    }
    return self;
}

- (NSDictionary *)jsonDictionary
{
    return self.receivedJson;
}

@end

@interface MSIDJsonSerializableMock2 : MSIDJsonSerializableMock

@end

@implementation MSIDJsonSerializableMock2

@end

@interface MSIDJsonSerializableFactoryTests : XCTestCase

@end

@implementation MSIDJsonSerializableFactoryTests

- (void)setUp
{
    [MSIDJsonSerializableFactory registerClass:MSIDJsonSerializableMock.class forClassType:@"my_class"];
}

- (void)tearDown
{
    [MSIDJsonSerializableFactory unregisterAll];
}

#pragma mark - Tests

- (void)testCreateFromJSONDictionary_whenCorrectClassTypeProvided_shouldCreateInstanceOfClass
{
    NSDictionary *json = @{@"key1": @"value1"};
    
    NSError *error;
    __auto_type instance = (MSIDJsonSerializableMock *)[MSIDJsonSerializableFactory createFromJSONDictionary:json classType:@"my_class" assertKindOfClass:MSIDJsonSerializableMock.class error:&error];
    
    XCTAssertNotNil(instance);
    XCTAssertNil(error);
    XCTAssertTrue([instance isKindOfClass:MSIDJsonSerializableMock.class]);
    XCTAssertEqualObjects(json, instance.receivedJson);
}

- (void)testCreateFromJSONDictionary_whenCorrectClassTypeProvidedButInvalidClassInstanceCreated_shouldReturnError
{
    NSDictionary *json = @{@"key1": @"value1"};
    
    NSError *error;
    __auto_type instance = (MSIDJsonSerializableMock *)[MSIDJsonSerializableFactory createFromJSONDictionary:json classType:@"my_class" assertKindOfClass:MSIDJsonSerializableMock2.class error:&error];
    
    XCTAssertNil(instance);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Failed to create object from json, created class instance is not of expected kind: MSIDJsonSerializableMock2.");
}

- (void)testCreateFromJSONDictionary_whenInvalidClassTypeProvided_shouldReturnError
{
    NSDictionary *json = @{@"key1": @"value1"};
    
    NSError *error;
    __auto_type instance = (MSIDJsonSerializableMock *)[MSIDJsonSerializableFactory createFromJSONDictionary:json classType:@"my_class_2" assertKindOfClass:MSIDJsonSerializableMock.class error:&error];
    
    XCTAssertNil(instance);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Failed to create object from json, class: MSIDJsonSerializableMock wasn't registered in factory under my_class_2 key.");
}

- (void)testCreateFromJSONDictionary_whenCorrectClassTypeJSONKeyProvided_shouldCreateInstanceOfClass
{
    NSDictionary *json = @{@"key1": @"value1",
                           @"my_class_type": @"my_class"
    };
    
    NSError *error;
    __auto_type instance = (MSIDJsonSerializableMock *)[MSIDJsonSerializableFactory createFromJSONDictionary:json classTypeJSONKey:@"my_class_type" assertKindOfClass:MSIDJsonSerializableMock.class error:&error];
    
    XCTAssertNotNil(instance);
    XCTAssertNil(error);
    XCTAssertTrue([instance isKindOfClass:MSIDJsonSerializableMock.class]);
    XCTAssertEqualObjects(json, instance.receivedJson);
}


- (void)testCreateFromJSONDictionary_whenCorrectClassTypeJSONKeyProvidedButInvalidClassInstanceCreated_shouldReturnError
{
    NSDictionary *json = @{@"key1": @"value1",
                           @"my_class_type": @"my_class"
    };
       
    NSError *error;
    __auto_type instance = (MSIDJsonSerializableMock *)[MSIDJsonSerializableFactory createFromJSONDictionary:json classTypeJSONKey:@"my_class_type" assertKindOfClass:MSIDJsonSerializableMock2.class error:&error];
    
    XCTAssertNil(instance);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Failed to create object from json, created class instance is not of expected kind: MSIDJsonSerializableMock2.");
}

- (void)testCreateFromJSONDictionary_whenInvalidClassTypeJSONKeyProvided_shouldReturnError
{
    NSDictionary *json = @{@"key1": @"value1",
                           @"my_class_type": @"my_class"
    };
    
    NSError *error;
    __auto_type instance = (MSIDJsonSerializableMock *)[MSIDJsonSerializableFactory createFromJSONDictionary:json classTypeJSONKey:@"my_class_type_2" assertKindOfClass:MSIDJsonSerializableMock.class error:&error];
    
    XCTAssertNil(instance);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"my_class_type_2 key is missing in dictionary.");
}

@end
