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

#import "MSIDBoundRefreshTokenRedemptionParameters.h"

@implementation MSIDBoundRefreshTokenRedemptionParameters

- (nonnull instancetype)initWithClientId:(nonnull NSString *)clientId scopes:(nonnull NSSet *)scopes nonce:(nonnull NSString *)nonce
{
    self = [super init];
    if (self)
    {
        if ([NSString msidIsStringNilOrBlank:clientId])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create bound refresh token redemption parameters: clientId is nil or blank.");
            return nil;
        }
        if (!scopes || scopes.count == 0)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create bound refresh token redemption parameters: scope is nil or empty.");
            return nil;
        }
        if ([NSString msidIsStringNilOrBlank:nonce])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create bound refresh token redemption parameters: nonce is nil or blank.");
            return nil;
        }
        
        _clientId = clientId;
        _scopes = scopes;
        _nonce = nonce;
    }
    return self;
}

- (nonnull NSMutableDictionary *)jsonDictionary
{
    NSMutableDictionary *jsonDict = [NSMutableDictionary new];
    jsonDict[MSID_OAUTH2_GRANT_TYPE] = MSID_OAUTH2_REFRESH_TOKEN;
    jsonDict[@"purpose"] = @"bound_rt_exchange"; // TODO: Add constants for purposes
    jsonDict[@"iss"] = self.clientId; // Issuer is the client ID
    NSNumber *now = @([[NSDate date] timeIntervalSince1970]);
    jsonDict[@"iat"] = [NSString stringWithFormat:@"%ld", [now longValue]]; // Issued at time
    jsonDict[@"exp"] = @([[NSDate dateWithTimeIntervalSinceNow:5 * 60] timeIntervalSince1970]); // 5 minutes
    jsonDict[@"nbf"] = [NSString stringWithFormat:@"%ld", [now longValue]]; // Not before time
    [jsonDict setObject:self.clientId forKey:MSID_OAUTH2_CLIENT_ID];
    [jsonDict setObject:self.nonce forKey:@"nonce"];
    NSString *scopeString = [self.scopes.allObjects componentsJoinedByString:@" "];
    [jsonDict setObject:scopeString forKey:MSID_OAUTH2_SCOPE];
    return jsonDict;
}

@end
