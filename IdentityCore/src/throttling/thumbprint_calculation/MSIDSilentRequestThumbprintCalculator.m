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
#import "MSIDThumbprintWrapperObject.h"
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
    NSArray *sortedThumbprintRequestList = [self sortRequestParametersUsingFilteredSet:self.fullThumbprintExcludeSet
                                                                       comparePolarity:NO];
    if (sortedThumbprintRequestList)
    {
        //TODO: use sortedArrayList to calculate Full Request Thumbprint
    }

    return nil;
}

- (NSString *)getStrictRequestThumbprint
{
    NSArray *sortedThumbprintRequestList = [self sortRequestParametersUsingFilteredSet:self.strictThumbprintIncludeSet
                                                                       comparePolarity:YES];
    if (sortedThumbprintRequestList)
    {
        //TODO: use sortedArrayList to calculate Strict Request Thumbprint
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
                MSIDThumbprintWrapperObject *thumbprintWrapperObject = [[MSIDThumbprintWrapperObject alloc] initWithParameters:key
                                                                                                                         value:obj];
                [arrayList addObject:thumbprintWrapperObject];
            }
        }
    }];
    
    NSArray *sortedArrayList = [arrayList sortedArrayUsingComparator:^NSComparisonResult(MSIDThumbprintWrapperObject *obj1, MSIDThumbprintWrapperObject *obj2)
    {
        return [obj1.key caseInsensitiveCompare:obj2.key];
    }];
    return sortedArrayList;
}

@end
