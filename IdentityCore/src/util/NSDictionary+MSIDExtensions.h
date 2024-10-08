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

@protocol MSIDRequestContext;

@interface NSDictionary (MSIDExtensions)

+ (NSDictionary *)msidDictionaryFromURLEncodedString:(NSString *)string;
+ (NSDictionary *)msidDictionaryFromWWWFormURLEncodedString:(NSString *)string;

- (NSString *)msidURLEncode;
- (NSString *)msidWWWFormURLEncode;

- (NSDictionary *)msidDictionaryByRemovingFields:(NSArray *)fieldsToRemove;
+ (NSDictionary *)msidDictionaryFromJSONString:(NSString *)jsonString;
- (NSString *)msidJSONSerializeWithContext:(id<MSIDRequestContext>)context;

- (NSDictionary *)msidDictionaryWithoutNulls;
- (NSString *)msidStringObjectForKey:(NSString *)key;
- (id)msidObjectForKey:(NSString *)key ofClass:(Class)requiredClass;
- (NSArray<NSNumber *>*)msidArrayOfIntegersForKey:(NSString *)key;
- (NSInteger)msidIntegerObjectForKey:(NSString *)key;
- (BOOL)msidBoolObjectForKey:(NSString *)key;

- (BOOL)msidAssertType:(Class)type ofKey:(NSString *)key required:(BOOL)required error:(NSError *__autoreleasing*)error;
- (BOOL)msidAssertTypeIsOneOf:(NSArray<Class> *)types ofKey:(NSString *)key required:(BOOL)required error:(NSError *__autoreleasing*)error;
- (BOOL)msidAssertTypeIsOneOf:(NSArray<Class> *)types
                        ofKey:(NSString *)key
                     required:(BOOL)required
                      context:(id<MSIDRequestContext>)context
                    errorCode:(NSInteger)errorCode
                        error:(NSError *__autoreleasing*)error;

- (NSDictionary *)msidNormalizedJSONDictionary;

- (NSMutableDictionary *)mutableDeepCopy;

@end
