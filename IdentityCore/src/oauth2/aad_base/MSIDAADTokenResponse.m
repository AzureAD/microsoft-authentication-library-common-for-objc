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

#import "MSIDAADTokenResponse.h"
#import "MSIDTokenResponse+Internal.h"
#import "MSIDTelemetryEventStrings.h"

@implementation MSIDAADTokenResponse

- (instancetype)initWithAccessToken:(NSString *)accessToken
                       refreshToken:(NSString *)refreshToken
                          expiresIn:(NSInteger)expiresIn
                          expiresOn:(NSInteger)expiresOn
                  extendedExpiresIn:(NSInteger)extendedExpiresIn
                  extendedExpiresOn:(NSInteger)extendedExpiresOn
                          tokenType:(NSString *)tokenType
                              scope:(NSString *)scope
                              state:(NSString *)state
                            idToken:(NSString *)idToken
               additionalServerInfo:(NSDictionary *)additionalServerInfo
                              error:(NSString *)error
                           suberror:(NSString *)suberror
                   errorDescription:(NSString *)errorDescription
                         clientInfo:(MSIDClientInfo *)clientInfo
                           familyId:(NSString *)familyId
                   additionalUserId:(NSString *)additionalUserId
                            speInfo:(NSString *)speInfo
                      correlationId:(NSString *)correlationId
{
    self = [super initWithAccessToken:accessToken
                         refreshToken:refreshToken
                            expiresIn:expiresIn
                            tokenType:tokenType
                                scope:scope
                                state:state
                              idToken:idToken
                 additionalServerInfo:additionalServerInfo
                                error:error
                     errorDescription:errorDescription];
    
    if (self)
    {
        _expiresOn = expiresOn;
        _extendedExpiresIn = extendedExpiresIn;
        _suberror = suberror;
        _clientInfo = clientInfo;
        _familyId = familyId;
        _additionalUserId = additionalUserId;
        _speInfo = speInfo;
        _correlationId = correlationId;
        
        [self initExtendedExpiresOnDate:extendedExpiresOn extendedExpiresIn:_extendedExpiresIn];
    }
    
    return self;
}

- (NSString *)description
{
    NSString *descr = [super description];
    return [NSString stringWithFormat:@"%@, familyID %@, suberror %@, additional user ID %@, clientInfo %@", descr, self.familyId, self.suberror, self.additionalUserId, self.clientInfo.rawClientInfo];
}

- (NSDate *)expiryDate
{
    NSDate *date = [super expiryDate];

    if (date) return date;

    NSInteger expiresOn = self.expiresOn;

    if (!expiresOn) return nil;

    return [NSDate dateWithTimeIntervalSince1970:expiresOn];
}

- (void)setAdditionalServerInfo:(NSDictionary *)additionalServerInfo
{
    NSArray *knownFields = @[MSID_OAUTH2_CORRELATION_ID_RESPONSE,
                             MSID_OAUTH2_RESOURCE,
                             MSID_OAUTH2_CLIENT_INFO,
                             MSID_FAMILY_ID,
                             MSID_TELEMETRY_KEY_SPE_INFO,
                             MSID_OAUTH2_EXPIRES_ON,
                             MSID_OAUTH2_EXT_EXPIRES_IN, @"url",
                             MSID_OAUTH2_SUB_ERROR];
    
    NSDictionary *additionalInfo = [additionalServerInfo dictionaryByRemovingFields:knownFields];
    
    [super setAdditionalServerInfo:additionalInfo];
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_CORRELATION_ID_RESPONSE required:NO error:error]) return nil;
        _correlationId = json[MSID_OAUTH2_CORRELATION_ID_RESPONSE];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_FAMILY_ID required:NO error:error]) return nil;
        _familyId = json[MSID_FAMILY_ID];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_TELEMETRY_KEY_SPE_INFO required:NO error:error]) return nil;
        _speInfo = json[MSID_TELEMETRY_KEY_SPE_INFO];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_SUB_ERROR required:NO error:error]) return nil;
        _suberror = json[MSID_OAUTH2_SUB_ERROR];
        
        if (![json msidAssertType:NSString.class ofKey:@"adi" required:NO error:error]) return nil;
        _additionalUserId = json[@"adi"];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_CLIENT_INFO required:NO error:error]) return nil;
        NSString *rawClientInfo = json[MSID_OAUTH2_CLIENT_INFO];
        
        NSError *localError;
        _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:rawClientInfo error:&localError];
        if (localError)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to init client info, error: %@", MSID_PII_LOG_MASKABLE(localError));
        }
        
        if (![json msidAssertType:NSNumber.class ofKey:MSID_OAUTH2_EXT_EXPIRES_IN required:NO error:error]) return nil;
        _extendedExpiresIn = [json[MSID_OAUTH2_EXT_EXPIRES_IN] integerValue];
        
        if (![json msidAssertType:NSNumber.class ofKey:@"ext_expires_on" required:NO error:error]) return nil;
        NSNumber *extendedExpiresOn = json[@"ext_expires_on"];
        
        if (![json msidAssertType:NSNumber.class ofKey:MSID_OAUTH2_EXPIRES_ON required:NO error:error]) return nil;
        _expiresOn = [json[MSID_OAUTH2_EXPIRES_ON] integerValue];
        
        [self initExtendedExpiresOnDate:[extendedExpiresOn integerValue] extendedExpiresIn:_extendedExpiresIn];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableDeepCopy];
    json[MSID_OAUTH2_CORRELATION_ID_RESPONSE] = self.correlationId;
    json[MSID_FAMILY_ID] = self.familyId;
    json[MSID_TELEMETRY_KEY_SPE_INFO] = self.speInfo;
    json[MSID_OAUTH2_SUB_ERROR] = self.suberror;
    json[@"adi"] = self.additionalUserId;
    json[MSID_OAUTH2_CLIENT_INFO] = self.clientInfo.rawClientInfo;
    json[MSID_OAUTH2_EXT_EXPIRES_IN] = @(self.extendedExpiresIn);
    json[@"ext_expires_on"] = @([self.extendedExpiresOnDate timeIntervalSince1970]);
    json[MSID_OAUTH2_EXPIRES_ON] = @(self.expiresOn);
    
    return json;
}

#pragma mark - Private

- (void)initExtendedExpiresOnDate:(NSInteger)extendedExpiresOn extendedExpiresIn:(NSInteger)extendedExpiresIn
{
    if (extendedExpiresIn)
    {
        _extendedExpiresOnDate = [NSDate dateWithTimeIntervalSinceNow:extendedExpiresIn];
    }
    else if (extendedExpiresOn)
    {
        // Broker could send ext_expires_on rather than ext_expires_in.
        _extendedExpiresOnDate = [NSDate dateWithTimeIntervalSince1970:extendedExpiresOn];
    }
}

@end
