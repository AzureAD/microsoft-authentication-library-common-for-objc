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
#import "MSIDHALLink.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Generic parser for HAL+JSON documents. Handles extraction of `_links` and
 `_embedded` sections, and exposes typed accessors for common HAL patterns.

 Shared across MSAL ecosystem SDKs (e.g. credential management) so HAL parsing
 lives in one place. Field-level mapping into domain models is the caller's job.
 */
@interface MSIDHALResource : NSObject

/** Raw JSON properties (excluding `_links` and `_embedded`). */
@property (nonatomic, readonly) NSDictionary<NSString *, id> *properties;

/** All links keyed by relation type. */
@property (nonatomic, readonly) NSDictionary<NSString *, NSArray<MSIDHALLink *> *> *links;

/** All embedded resources keyed by relation type. */
@property (nonatomic, readonly) NSDictionary<NSString *, NSArray<NSDictionary<NSString *, id> *> *> *embedded;

/** Parses a HAL resource from a JSON dictionary. */
- (instancetype)initWithJSON:(NSDictionary *)json;

/** Returns the first link for the given relation, or nil if not present. */
- (nullable MSIDHALLink *)linkForRelation:(NSString *)relation;

/** Returns all links for the given relation. */
- (NSArray<MSIDHALLink *> *)allLinksForRelation:(NSString *)relation;

/** Returns embedded resources for the given relation. */
- (NSArray<NSDictionary<NSString *, id> *> *)embeddedResourcesForRelation:(NSString *)relation;

/** Returns a string property value for the given key, or nil. */
- (nullable NSString *)stringForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
