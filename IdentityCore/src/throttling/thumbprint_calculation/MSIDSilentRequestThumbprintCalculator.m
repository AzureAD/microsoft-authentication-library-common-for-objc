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


#import <Foundation/Foundation.h>
#import "MSIDSilentRequestThumbprintCalculator.h"
#import "MSIDOAuth2Constants.h"

@interface MSIDSilentRequestThumbprintCalculator ()

@property (nonatomic) NSMutableDictionary *requestParameters;
@property (nonatomic) NSSet *strictThumbprintIncludeSet; //white list for items to include for strict request thumbprint calculation
@property (nonatomic) NSSet *fullThumbprintExcludeSet; //black list for items to exclude from full request thumbprint calculation

@end

@implementation MSIDSilentRequestThumbprintCalculator

- (instancetype)initWithParamaters:(NSDictionary *)parameters
                       endpointUrl:(NSString *)endpointUrl
                             realm:(NSString *)realm
                       environment:(NSString *)environment
                     homeAccountId:(NSString *)homeAccountId
{
    self = [super init];
    if (self)
    {
        _requestParameters = [parameters mutableCopy];
        _requestParameters[@"endpointUrl"] = endpointUrl;
        _requestParameters[@"realm"] = realm;
        _requestParameters[@"environment"] = environment;
        _requestParameters[@"homeAccountId"] = homeAccountId;
        _strictThumbprintIncludeSet = [NSSet setWithArray:@[@"realm",@"environment",@"homeAccountId",MSID_OAUTH2_CLIENT_ID,MSID_OAUTH2_SCOPE]];
        _fullThumbprintExcludeSet = [NSSet new];
    }
    return self;
}

- (NSString *)getFullRequestThumbprint
{
    NSString *fullRequestThumbprintKey = [self getRequestThumbprintImpl:self.fullThumbprintExcludeSet
                                                        comparePolarity:NO];
    if (!fullRequestThumbprintKey)
    {
        //Log Error
        return nil;
    }
    return fullRequestThumbprintKey;
}

- (NSString *)getStrictRequestThumbprint
{
    NSString *strictRequestThumbprintKey = [self getRequestThumbprintImpl:self.strictThumbprintIncludeSet
                                                          comparePolarity:YES];
    if (!strictRequestThumbprintKey)
    {
        //Log Error
        return nil;
    }
    return strictRequestThumbprintKey;
}

- (NSString *)getRequestThumbprintImpl:(NSSet *)filteringSet
                       comparePolarity:(BOOL)comparePolarity
{
    NSArray *sortedThumbprintRequestList = [self sortRequestParametersUsingFilteredSet:filteringSet
                                                                       comparePolarity:comparePolarity];
    if (sortedThumbprintRequestList)
    {
        NSUInteger thumbprintKey = [self hash:sortedThumbprintRequestList];
        if (thumbprintKey == 0)
        {
            return nil;
        }
        
        else
        {
            return [NSString stringWithFormat: @"%lu", thumbprintKey];
        }
    }
    return nil;
}

- (NSArray *)sortRequestParametersUsingFilteredSet:(NSSet *)filteringSet
                                   comparePolarity:(BOOL)comparePolarity
{
    NSMutableArray *arrayList = [NSMutableArray new];
    [self.requestParameters enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, __unused BOOL * _Nonnull stop) {
        if ([key isKindOfClass:[NSString class]] && [obj isKindOfClass:[NSString class]])
        {
            if ([filteringSet containsObject:key] == comparePolarity)
            {
                NSArray *thumbprintObject = [NSArray arrayWithObjects:key, obj, nil];
                [arrayList addObject:thumbprintObject];
            }
        }
    }];
    
    NSArray *sortedArrayList = [arrayList sortedArrayUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2)
    {
        return [[obj1 objectAtIndex:0] caseInsensitiveCompare:[obj2 objectAtIndex:0]];
    }];
    return sortedArrayList;
}

- (NSUInteger)hash:(NSArray *)thumbprintRequestList
{
    if (!thumbprintRequestList) return 0;
    
    NSUInteger hash = [super hash];
    for (id object in thumbprintRequestList)
    {
        if ([object isKindOfClass:[NSString class]])
        {
            hash = hash * 31 + ((NSString *)object).hash;
        }
        
        else
        {
            return 0;
        }
    }
    return hash;
}


@end
