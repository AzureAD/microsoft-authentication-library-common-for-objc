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

#import "MSIDPKeyAuthHandler.h"
#import "MSIDChallengeHandler.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDPkeyAuthHelper.h"
#import "MSIDHelpers.h"
#import "MSIDError.h"
#import "MSIDDeviceId.h"
#import "MSIDConstants.h"
#import "NSDictionary+MSIDExtensions.h"
#if !EXCLUDE_FROM_MSALCPP
#import "MSIDCurrentRequestTelemetry.h"
#import "MSIDRequestTelemetryConstants.h"
#endif
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDExecutionFlowLogger.h"
#import "MSIDExecutionFlowConstants.h"
#import "MSIDFlightManager.h"

@implementation MSIDPKeyAuthHandler

+ (BOOL)handleChallenge:(NSString *)challengeUrl
                context:(id<MSIDRequestContext>)context
          customHeaders:(NSDictionary<NSString *, NSString *> *)customHeaders
     externalSSOContext:(MSIDExternalSSOContext *)externalSSOContext
      completionHandler:(void (^)(NSURLRequest *challengeResponse, NSError *error))completionHandler
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Handling PKeyAuth Challenge.");
    
    NSArray *parts = [challengeUrl componentsSeparatedByString:@"?"];
    NSString *qp = [parts objectAtIndex:1];
    NSDictionary *queryParamsMap = [NSDictionary msidDictionaryFromURLEncodedString:qp];
    NSString *submitUrl = [queryParamsMap valueForKey:@"SubmitUrl"];
    
    // Fail if the PKeyAuth challenge doesn't contain the required info
    NSError *error = nil;
    if (!queryParamsMap || !submitUrl)
    {
        error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerOauth, @"Incomplete PKeyAuth challenge received.", nil, nil, nil, context.correlationId, nil, YES);
        completionHandler(nil, error);
        return YES;
    }
    
    // Extract authority from submit url    
    NSString *authHeader = [MSIDPkeyAuthHelper createDeviceAuthResponse:[NSURL URLWithString:submitUrl]
                                                          challengeData:queryParamsMap
                                                     externalSSOContext:externalSSOContext
                                                                context:context];
    
    // Attach client version to response url
    NSURLComponents *responseUrlComp = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:submitUrl] resolvingAgainstBaseURL:NO];
    NSMutableDictionary *queryDict = [NSMutableDictionary new];
    
    for (NSURLQueryItem *item in responseUrlComp.queryItems)
    {
        [queryDict setValue:item.value forKey:item.name];
    }
    [queryDict setValue:MSIDDeviceId.deviceId[MSID_VERSION_KEY] forKey:MSID_VERSION_KEY];
    responseUrlComp.percentEncodedQuery = [queryDict msidURLEncode];
    
    NSMutableURLRequest *responseReq = [[NSMutableURLRequest alloc] initWithURL:responseUrlComp.URL];
    [responseReq setValue:kMSIDPKeyAuthHeaderVersion forHTTPHeaderField:kMSIDPKeyAuthHeader];
    [responseReq setValue:authHeader forHTTPHeaderField:MSID_OAUTH2_AUTHORIZATION];
    
#if !EXCLUDE_FROM_MSALCPP
    MSIDCurrentRequestTelemetry *telemetry = [MSIDCurrentRequestTelemetry new];
    telemetry.schemaVersion = HTTP_REQUEST_TELEMETRY_SCHEMA_VERSION;
    BOOL v2GroupEntitled = [MSIDWorkPlaceJoinUtil v2AccessGroupAllowedWithContext:context];
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"v2 WPJ group is allowed %d", v2GroupEntitled);
    NSMutableArray *platformFields = [NSMutableArray new];
    [platformFields addObject:v2GroupEntitled ? MSID_WPJ_V2_TELEMETRY_KEY : MSID_WPJ_V1_TELEMETRY_KEY];
    telemetry.platformFields = platformFields;
    NSString *currentRequestTelemetryString = [telemetry telemetryString];
    [responseReq setValue:currentRequestTelemetryString forHTTPHeaderField:MSID_CURRENT_TELEMETRY_HEADER_NAME];
#endif
    
    // Adding refreshTokenCredential (PRT) header to the challenge response. Header is available in customheaders dictionary.
    // Only attach the PRT header when the challenge is being submitted to a known AAD host, to avoid leaking it to untrusted hosts.
    NSString *credentialHeader = [customHeaders objectForKey:MSID_REFRESH_TOKEN_CREDENTIAL];
    if (credentialHeader)
    {
        NSString *submitHost = [NSURL URLWithString:submitUrl].host.lowercaseString;
        if (submitHost && [[MSIDAADNetworkConfiguration defaultConfiguration] isAADPublicCloud:submitHost])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Added refresh token to the PkeyAuth response.");
            [responseReq setValue:credentialHeader forHTTPHeaderField:MSID_REFRESH_TOKEN_CREDENTIAL];
            if (context.correlationId)
            {
                MSIDExecutionFlowInsertTag(MSIDStringFromPkeyAuthTag(MSIDPkeyAuthAddedRefreshTokenCredentialTag), nil, context.correlationId);
            }
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Skipped adding refresh token to the PkeyAuth response because the submit URL host is not a known AAD host.");
            if (context.correlationId)
            {
                MSIDExecutionFlowInsertTag(MSIDStringFromPkeyAuthTag(MSIDPkeyAuthSkippedRefreshTokenCredentialUntrustedHostTag), nil, context.correlationId);
            }
        }
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"CredentialHeader is nil while responding to PKeyAuth Challenge.");
    }

    completionHandler(responseReq, nil);
    return YES;
}

+ (void)handleWwwAuthenticateHeader:(NSString *)wwwAuthHeaderValue
                         requestUrl:(NSURL *)requestUrl
                 externalSSOContext:(MSIDExternalSSOContext *)externalSSOContext
                            context:(id<MSIDRequestContext>)context
                  completionHandler:(void (^)(NSString *authHeader, NSError *error))completionHandler
{
    [self handleWwwAuthenticateHeader:wwwAuthHeaderValue
                           requestUrl:requestUrl
                         httpResponse:nil
                   externalSSOContext:externalSSOContext
                              context:context
                    completionHandler:completionHandler];
}

+ (void)handleWwwAuthenticateHeader:(NSString *)wwwAuthHeaderValue
                         requestUrl:(NSURL *)requestUrl
                       httpResponse:(NSHTTPURLResponse *)httpResponse
                 externalSSOContext:(MSIDExternalSSOContext *)externalSSOContext
                            context:(id<MSIDRequestContext>)context
                  completionHandler:(void (^)(NSString *authHeader, NSError *error))completionHandler
{
    NSDictionary *authHeaderParams = [self parseAuthHeader:wwwAuthHeaderValue];
    
    if (!authHeaderParams)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, context, @"Unparseable wwwAuthHeader received %@", MSID_EUII_ONLY_LOG_MASKABLE(wwwAuthHeaderValue));
    }
    
    NSDate *serverTime = nil;
    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_ENABLE_PKEYAUTH_SERVER_TIME])
    {
        if (authHeaderParams && [wwwAuthHeaderValue isEqualToString:[httpResponse valueForHTTPHeaderField:kMSIDWwwAuthenticateHeader]])
        {
            serverTime = [self serverTimeFromResponse:httpResponse requestUrl:requestUrl context:context];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"PKeyAuth server time unavailable: missing or mismatched challenge response. Using local clock.");
        }
    }

    NSError *error = nil;
    NSString *authHeader = [MSIDPkeyAuthHelper createDeviceAuthResponse:requestUrl
                                                          challengeData:authHeaderParams
                                                     externalSSOContext:externalSSOContext
                                                             serverTime:serverTime
                                                                context:context];
    if (completionHandler)
    {
        completionHandler(authHeader, error);
    }
}

+ (NSDate *)serverTimeFromResponse:(NSHTTPURLResponse *)response
                        requestUrl:(NSURL *)requestUrl
                           context:(id<MSIDRequestContext>)context
{
    NSURL *responseUrl = response.URL;
    if ((response.statusCode != 400 && response.statusCode != 401)
        || ![responseUrl isEqual:requestUrl]
        || ![responseUrl.scheme.lowercaseString isEqualToString:@"https"]
        || (responseUrl.port && responseUrl.port.integerValue != 443)
        || ![MSIDAADNetworkConfiguration.defaultConfiguration isAADPublicCloud:responseUrl.host.lowercaseString])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"PKeyAuth server time unavailable: response is not a matching HTTPS ESTS challenge. Using local clock.");
        return nil;
    }

    NSString *age = [response valueForHTTPHeaderField:@"Age"];
    if (age && ![age isEqualToString:@"0"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"PKeyAuth server time unavailable: aged challenge response. Using local clock.");
        return nil;
    }

    NSString *dateHeader = [response valueForHTTPHeaderField:@"Date"];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
    formatter.lenient = NO;
    NSDate *serverTime = dateHeader ? [formatter dateFromString:dateHeader] : nil;
    // Round-trip validation rejects partial parses, normalized invalid dates, and non-GMT values.
    if (!serverTime || serverTime.timeIntervalSince1970 <= 0 || ![[formatter stringFromDate:serverTime] isEqualToString:dateHeader])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"PKeyAuth server time unavailable: missing or invalid HTTP Date. Using local clock.");
        return nil;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"PKeyAuth assertion uses server time from the current trusted ESTS challenge.");
    return serverTime;
}

// Decodes the parameters that come in the Authorization header. We expect them in the following
// format:
//
// <key>="<value>", key="<value>", key="<value>"
// i.e. version="1.0",CertAuthorities="OU=MyOrganization,CN=MyThingy,DN=windows,DN=net",Context="context!"
//
// This parser is lenient on whitespace, and on the presence of enclosing quotation marks. It also
// will allow commented out quotation marks
+ (NSDictionary *)parseAuthHeader:(NSString *)authHeader
{
    if (!authHeader)
    {
        return nil;
    }
    
    //pkeyauth word length=8 + 1 whitespace
    authHeader = [authHeader substringFromIndex:[kMSIDPKeyAuthName length] + 1];
    
    NSMutableDictionary *params = [NSMutableDictionary new];
    NSUInteger strLength = [authHeader length];
    NSRange currentRange = NSMakeRange(0, strLength);
    NSCharacterSet *whiteChars = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSCharacterSet *alphaNum = [NSCharacterSet alphanumericCharacterSet];
    
    while (currentRange.location < strLength)
    {
        // Eat up any whitepace at the beginning
        while (currentRange.location < strLength && [whiteChars characterIsMember:[authHeader characterAtIndex:currentRange.location]])
        {
            ++currentRange.location;
            --currentRange.length;
        }
        
        if (currentRange.location == strLength)
        {
            return params;
        }
        
        if (![alphaNum characterIsMember:[authHeader characterAtIndex:currentRange.location]])
        {
            // malformed string
            return nil;
        }
        
        // Find the key
        NSUInteger found = [authHeader rangeOfString:@"=" options:0 range:currentRange].location;
        // If there are no keys left then exit out
        if (found == NSNotFound)
        {
            // If there still is string left that means it's malformed
            if (currentRange.length > 0)
            {
                return nil;
            }
            
            // Otherwise we're at the end, return params
            return params;
        }
        NSUInteger length = found - currentRange.location;
        NSString *key = [authHeader substringWithRange:NSMakeRange(currentRange.location, length)];
        
        // don't want the '='
        ++length;
        currentRange.location += length;
        currentRange.length -= length;
        
        NSString *value = nil;
        
        
        if ([authHeader characterAtIndex:currentRange.location] == '"')
        {
            ++currentRange.location;
            --currentRange.length;
            
            found = currentRange.location;
            
            do {
                NSRange range = NSMakeRange(found, strLength - found);
                found = [authHeader rangeOfString:@"\"" options:0 range:range].location;
            } while (found != NSNotFound && [authHeader characterAtIndex:found-1] == '\\');
            
            // If we couldn't find a matching closing quote then we have a malformed string and return NULL
            if (found == NSNotFound)
            {
                return nil;
            }
            
            length = found - currentRange.location;
            value = [authHeader substringWithRange:NSMakeRange(currentRange.location, length)];
            
            ++length;
            currentRange.location += length;
            currentRange.length -= length;
            
            // find the next comma
            found = [authHeader rangeOfString:@"," options:0 range:currentRange].location;
            if (found != NSNotFound)
            {
                length = found - currentRange.location;
            }
            
        }
        else
        {
            found = [authHeader rangeOfString:@"," options:0 range:currentRange].location;
            // If we didn't find the comma that means we're at the end of the list
            if (found == NSNotFound)
            {
                length = currentRange.length;
            }
            else
            {
                length = found - currentRange.location;
            }
            
            value = [authHeader substringWithRange:NSMakeRange(currentRange.location, length)];
        }
        
        NSString *existingValue = [params valueForKey:key];
        if (existingValue)
        {
            [params setValue:[existingValue stringByAppendingFormat:@".%@", value] forKey:key];
        }
        else
        {
            [params setValue:value forKey:key];
        }
        
        ++length;
        currentRange.location += length;
        currentRange.length -= length;
    }
    
    return params;
}

@end
