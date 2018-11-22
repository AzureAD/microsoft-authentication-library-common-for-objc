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

#import "MSIDLegacyBrokerTokenRequest.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "NSMutableDictionary+MSIDExtensions.h"

@implementation MSIDLegacyBrokerTokenRequest

#pragma mark - Abstract impl

// Those parameters will be different depending on the broker protocol version
- (NSDictionary *)protocolPayloadContentsWithError:(NSError **)error
{
    NSString *skipCacheValue = @"NO";

    if ([self.requestParameters.claims count])
    {
        skipCacheValue = @"YES";
    }

    NSString *usernameType = @"";
    NSString *username = @"";

    if (self.requestParameters.accountIdentifier.legacyAccountId)
    {
        username = self.requestParameters.accountIdentifier.legacyAccountId;
        usernameType = [MSIDAccountIdentifier legacyAccountIdentifierAsString:self.requestParameters.accountIdentifier.legacyAccountIdentifierType];
    }
    else if (self.requestParameters.loginHint)
    {
        username = self.requestParameters.loginHint;
        usernameType = [MSIDAccountIdentifier legacyAccountIdentifierAsString:MSIDLegacyIdentifierTypeOptionalDisplayableId];
    }

    NSMutableDictionary *contents = [NSMutableDictionary new];
    [contents msidSetNonEmptyString:skipCacheValue forKey:@"skip_cache"];
    [contents msidSetNonEmptyString:self.requestParameters.target forKey:@"resource"];
    [contents msidSetNonEmptyString:self.requestParameters.uiBehaviorType == MSIDUIBehaviorForceType ? @"YES" : @"NO" forKey:@"force"];
    [contents msidSetNonEmptyString:username forKey:@"username"];
    [contents msidSetNonEmptyString:usernameType forKey:@"username_type"];
    [contents msidSetNonEmptyString:@"2" forKey:@"max_protocol_ver"];

    return contents;
}

- (NSDictionary *)protocolResumeDictionaryContents
{
    return @{@"resource": self.requestParameters.target ?: @""};
}

@end
