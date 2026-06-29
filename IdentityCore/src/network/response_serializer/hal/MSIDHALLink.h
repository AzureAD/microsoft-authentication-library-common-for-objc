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

NS_ASSUME_NONNULL_BEGIN

/**
 Represents a HAL Link Object as defined by the JSON-HAL specification.
 See: https://www.ietf.org/archive/id/draft-kelly-json-hal-11.html
 */
@interface MSIDHALLink : NSObject

/** The URI of the linked resource. */
@property (nonatomic, readonly) NSString *href;

/** Secondary key distinguishing links within the same relation. */
@property (nonatomic, readonly, nullable) NSString *name;

/** Whether `href` is a URI Template (RFC 6570). */
@property (nonatomic, readonly) BOOL templated;

/** Parses a HAL Link Object from a JSON dictionary. Returns nil when `href` is missing. */
- (nullable instancetype)initWithJSON:(NSDictionary *)json;

@end

NS_ASSUME_NONNULL_END
