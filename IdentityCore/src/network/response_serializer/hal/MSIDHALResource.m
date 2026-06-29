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

#import "MSIDHALResource.h"

@interface MSIDHALResource ()

@property (nonatomic) NSDictionary<NSString *, id> *properties;
@property (nonatomic) NSDictionary<NSString *, NSArray<MSIDHALLink *> *> *links;
@property (nonatomic) NSDictionary<NSString *, NSArray<NSDictionary<NSString *, id> *> *> *embedded;

@end

@implementation MSIDHALResource

- (instancetype)initWithJSON:(NSDictionary *)json
{
    self = [super init];

    if (self)
    {
        NSMutableDictionary *props = [json mutableCopy];
        NSMutableDictionary<NSString *, NSArray<MSIDHALLink *> *> *parsedLinks = [NSMutableDictionary new];
        NSMutableDictionary<NSString *, NSArray<NSDictionary<NSString *, id> *> *> *parsedEmbedded = [NSMutableDictionary new];

        NSDictionary *linksJson = [json[@"_links"] isKindOfClass:[NSDictionary class]] ? json[@"_links"] : nil;

        if (linksJson)
        {
            for (NSString *rel in linksJson)
            {
                if ([rel isEqualToString:@"curies"]) continue;

                id value = linksJson[rel];

                if ([value isKindOfClass:[NSDictionary class]])
                {
                    MSIDHALLink *link = [[MSIDHALLink alloc] initWithJSON:value];
                    if (link) parsedLinks[rel] = @[link];
                }
                else if ([value isKindOfClass:[NSArray class]])
                {
                    NSMutableArray<MSIDHALLink *> *linkArray = [NSMutableArray new];
                    for (id item in (NSArray *)value)
                    {
                        if ([item isKindOfClass:[NSDictionary class]])
                        {
                            MSIDHALLink *link = [[MSIDHALLink alloc] initWithJSON:item];
                            if (link) [linkArray addObject:link];
                        }
                    }
                    parsedLinks[rel] = linkArray;
                }
            }
            [props removeObjectForKey:@"_links"];
        }

        NSDictionary *embeddedJson = [json[@"_embedded"] isKindOfClass:[NSDictionary class]] ? json[@"_embedded"] : nil;

        if (embeddedJson)
        {
            for (NSString *rel in embeddedJson)
            {
                id value = embeddedJson[rel];

                if ([value isKindOfClass:[NSArray class]])
                {
                    parsedEmbedded[rel] = value;
                }
                else if ([value isKindOfClass:[NSDictionary class]])
                {
                    parsedEmbedded[rel] = @[value];
                }
            }
            [props removeObjectForKey:@"_embedded"];
        }

        _properties = props;
        _links = parsedLinks;
        _embedded = parsedEmbedded;
    }

    return self;
}

- (nullable MSIDHALLink *)linkForRelation:(NSString *)relation
{
    return self.links[relation].firstObject;
}

- (NSArray<MSIDHALLink *> *)allLinksForRelation:(NSString *)relation
{
    return self.links[relation] ?: @[];
}

- (NSArray<NSDictionary<NSString *, id> *> *)embeddedResourcesForRelation:(NSString *)relation
{
    return self.embedded[relation] ?: @[];
}

- (nullable NSString *)stringForKey:(NSString *)key
{
    id value = self.properties[key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

@end
