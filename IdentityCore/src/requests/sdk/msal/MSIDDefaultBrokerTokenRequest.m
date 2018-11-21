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

#import "MSIDDefaultBrokerTokenRequest.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAccountIdentifier.h"

@implementation MSIDDefaultBrokerTokenRequest

// Those parameters will be different depending on the broker protocol version
- (NSDictionary *)protocolPayloadContentsWithError:(NSError **)error
{
    NSString *homeAccountId = self.requestParameters.accountIdentifier.homeAccountId;
    NSString *username = self.requestParameters.accountIdentifier.legacyAccountId;
    
    // if value is nil, it won't appear in the dictionary
    NSMutableDictionary *contents = [NSMutableDictionary new];
    [contents setValue:self.requestParameters.allTokenRequestScopes forKey:@"scope"];
    [contents setValue:homeAccountId forKey:@"home_account_id"];
    [contents setValue:username forKey:@"username"];
    [contents setValue:self.requestParameters.loginHint forKey:@"login_hint"];
    [contents setValue:self.requestParameters.extraScopesToConsent forKey:@"extra_consent_scopes"];
    [contents setValue:self.requestParameters.promptType forKey:@"prompt"];
    [contents setValue:@"3" forKey:@"msg_protocol_ver"];
    
    return contents;
}

- (NSDictionary *)protocolResumeDictionaryContents
{
    return @{@"scope": self.requestParameters.target ?: @""};
}

@end
