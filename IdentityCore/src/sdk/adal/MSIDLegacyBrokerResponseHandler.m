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

#import "MSIDLegacyBrokerResponseHandler.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerResponse.h"
#import "MSIDAADV1BrokerResponse.h"

@implementation MSIDLegacyBrokerResponseHandler

- (MSIDTokenResult *)processAndSaveBrokerResultWithQueryParams:(NSDictionary *)encryptedParams
                                                         error:(NSError **)error
{
    return nil;
}

- (MSIDBrokerResponse *)brokerResponseFromEncryptedQueryParams:(NSDictionary *)encryptedParams
                                                 correlationId:(NSUUID *)correlationID
                                                         error:(NSError **)error
{
    if (encryptedParams[MSID_OAUTH2_ERROR_DESCRIPTION])
    {
        // In the case where Intune App Protection Policies are required, the broker may send back the Intune MAM Resource token
        if (encryptedParams[@"intune_mam_token_hash"] && encryptedParams[@"intune_mam_token"])
        {
            NSDictionary *intuneResponseDictionary = @{@"response": encryptedParams[@"intune_mam_token"],
                                                       @"hash": encryptedParams[@"intune_mam_token_hash"],
                                                       // TODO: default was 1 in ADAL
                                                       @"msg_protocol_ver": encryptedParams[@"msg_protocol_ver"] ?: @2};

            NSDictionary *decryptedResponse = [super responseDictionaryFromEncryptedQueryParams:intuneResponseDictionary
                                                                                  correlationId:correlationID
                                                                                          error:error];

            if (!decryptedResponse)
            {
                return nil;
            }

            MSIDAADV1BrokerResponse *brokerResponse = [[MSIDAADV1BrokerResponse alloc] initWithDictionary:decryptedResponse error:error];


            // TODO: we should save it here and return error! Check ADAL code!

            return brokerResponse;
        }
        else
        {
            // V1 protocol doesn't return encrypted response in the case of failure
            MSIDAADV1BrokerResponse *brokerResponse = [[MSIDAADV1BrokerResponse alloc] initWithDictionary:encryptedParams error:error];

            if (!brokerResponse)
            {
                return nil;
            }

            NSError *brokerError = [self resultFromBrokerErrorResponse:brokerResponse];

            if (error)
            {
                *error = brokerError;
            }

            return nil;
        }
    }

    NSDictionary *decryptedResponse = [super responseDictionaryFromEncryptedQueryParams:encryptedParams
                                                                          correlationId:correlationID
                                                                                  error:error];

    if (!decryptedResponse)
    {
        return nil;
    }

    return [[MSIDAADV1BrokerResponse alloc] initWithDictionary:decryptedResponse error:error];
}

- (NSError *)resultFromBrokerErrorResponse:(MSIDAADV1BrokerResponse *)errorResponse
{
    NSUUID *correlationId = [[NSUUID alloc] initWithUUIDString:errorResponse.correlationId];
    NSString *errorDescription = errorResponse.errorDescription;

    if (!errorDescription)
    {
        errorDescription = @"Broker did not provide any details";
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary new];

    if (errorResponse.brokerAppVer)
    {
        userInfo[@"x-broker-app-ver"] = errorResponse.brokerAppVer;
    }

    NSString *stsErrorCode = errorResponse.errorCode;
    NSInteger errorCode = MSIDErrorBrokerUnknown;

    if (stsErrorCode && ![stsErrorCode isEqualToString:@"0"])
    {
        errorCode = [stsErrorCode integerValue];
    }

    userInfo[MSIDOAuthSubErrorKey] = errorResponse.subError;

    // TODO: it's quite fragile that older broker returns this error as integer, what if integer gets changes?
    if (errorCode == 213)
    {
        userInfo[MSIDUserDisplayableIdkey] = errorResponse.userId;
    }

    NSString *oauthErrorCode = errorResponse.oauthErrorCode;
    NSString *errorDomain = errorResponse.errorDomain ?: MSIDErrorDomain;

    if (errorResponse.httpHeaders)
    {
        NSDictionary *httpHeaders = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:errorResponse.httpHeaders];
        userInfo[MSIDHTTPHeadersKey] = httpHeaders;
    }

    NSError *brokerError = MSIDCreateError(errorDomain, errorCode, errorDescription, oauthErrorCode, errorResponse.subError, nil, correlationId, userInfo);

    return brokerError;
}

@end
