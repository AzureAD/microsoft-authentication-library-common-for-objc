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
#import "MSIDSSOSilentRequestThumbprintCalculator.h"
#import "MSIDTokenRequest.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDConfiguration.h"
#import "MSIDAuthority.h"
#import "MSIDBrokerConstants.h"

static NSString *const MSID_ACCOUNT_DISPLAYABLE_ID_JSON_KEY = @"username";
static NSString *const MSID_ACCOUNT_HOME_ID_JSON_KEY = @"home_account_id";

@interface MSIDSilentRequestThumbprintCalculator (MSIDSSOSilentRequestThumbprintCalculator)

- (NSArray *)sortRequestParametersUsingFilteredSet:(NSSet *)filteringSet
                                   comparePolarity:(BOOL)comparePolarity;

- (NSString *)getRequestThumbprintImpl:(NSSet *)filteringSet
                       comparePolarity:(BOOL)comparePolarity;

@end


//Exclude:
//1) MSID_ACCOUNT_DISPLAYABLE_ID_JSON_KEY (username), since home_account_id serves the same purpose
//2) client-related items, since they are the same across all requests
//  i)MSID_BROKER_CLIENT_CAPABILITIES_KEY
// ii)MSID_BROKER_CLIENT_VERSION_KEY
//iii)MSID_BROKER_CLIENT_APP_VERSION_KEY
// iv)MSID_BROKER_CLIENT_APP_NAME_KEY
//  v)MSID_BROKER_CORRELATION_ID_KEY (correlation id is a randomly generated guid)
// vi)MSID_CLIENT_ID_JSON_KEY

@interface MSIDSSOSilentRequestThumbprintCalculator ()

@property (nonatomic) NSMutableDictionary *requestParameters;
@property (nonatomic) NSSet *strictThumbprintIncludeSet; //white list for items to include for strict request thumbprint calculation
@property (nonatomic) NSSet *fullThumbprintExcludeSet; //black list for items to exclude from full request thumbprint calculation

@end

@implementation MSIDSSOSilentRequestThumbprintCalculator

- (instancetype)initWithParamaters:(NSDictionary *)parameters
{
    self = [super init];
    if (self)
    {
        _requestParameters = [parameters mutableCopy];
        _strictThumbprintIncludeSet = [NSSet setWithArray:@[MSID_SCOPE_JSON_KEY,
                                                            MSID_AUTHORITY_URL_JSON_KEY,
                                                            MSID_ACCOUNT_HOME_ID_JSON_KEY]];
        _fullThumbprintExcludeSet = [NSSet setWithArray:@[MSID_ACCOUNT_DISPLAYABLE_ID_JSON_KEY,
                                                          MSID_BROKER_CLIENT_CAPABILITIES_KEY,
                                                          MSID_BROKER_CLIENT_VERSION_KEY,
                                                          MSID_BROKER_CLIENT_APP_VERSION_KEY,
                                                          MSID_BROKER_CLIENT_APP_NAME_KEY,
                                                          MSID_BROKER_CORRELATION_ID_KEY,
                                                          MSID_CLIENT_ID_JSON_KEY]];
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


@end
