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

    NSString *usernameType = [MSIDAccountIdentifier legacyAccountIdentifierAsString:self.requestParameters.accountIdentifier.legacyAccountIdentifierType];

    NSString *username = self.requestParameters.accountIdentifier.legacyAccountId;

    if (!username)
    {
        username = self.requestParameters.loginHint;
        usernameType = [MSIDAccountIdentifier legacyAccountIdentifierAsString:MSIDLegacyIdentifierTypeOptionalDisplayableId];
    }

    NSDictionary *contents =
    @{
      @"skip_cache": skipCacheValue,
      @"resource": self.requestParameters.target ?: @"",
      @"force": self.requestParameters.uiBehaviorType == MSIDUIBehaviorForceType ? @"YES" : @"NO",
      @"username": username ?: @"",
      @"username_type": usernameType,
      @"max_protocol_ver": @"2"
    };

    return contents;
}

- (NSDictionary *)protocolResumeDictionaryContents
{
    return @{@"resource": self.requestParameters.target ?: @""};
}

@end
