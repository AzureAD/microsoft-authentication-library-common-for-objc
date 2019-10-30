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

#import <Foundation/Foundation.h>

@protocol MSIDJsonSerializable;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDJsonSerializableFactory : NSObject

/*!
 Bind class type with sepcifc class type key in json paylod.
 This method is tread safe.
 */
+ (void)registerClass:(Class<MSIDJsonSerializable>)value forKey:(NSString *)key;

/*!
 Unbind all registered classes.
 This method is tread safe.
 */
+ (void)unregisterAll;


/*!
 Create instance of class from the provided json payload.
 This method is not thread safe.
 @param json JSON payload.
 @param classTypeJSONKey Key in json payload which should be used to get class type value. All classes are registered
 under this class type value in this factory.
 @param aClass Verify created class instance is kind of aClass.
 */
+ (id<MSIDJsonSerializable>)createFromJSONDictionary:(NSDictionary *)json
                                    classTypeJSONKey:(NSString *)classTypeJSONKey
                                   assertKindOfClass:(Class)aClass
                                               error:(NSError **)error;

/*!
Create instance of class from the provided json payload.
This method is not thread safe.
@param json JSON payload.
@param classTypeValue Class type value under which class is registered in this factory.
 @param aClass Verify created class instance is kind of aClass.
*/
+ (id<MSIDJsonSerializable>)createFromJSONDictionary:(NSDictionary *)json
                                      classTypeValue:(NSString *)classTypeValue
                                   assertKindOfClass:(Class)aClass
                                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
