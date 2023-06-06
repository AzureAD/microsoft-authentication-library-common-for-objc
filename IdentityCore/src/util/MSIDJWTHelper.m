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

#import "MSIDJWTHelper.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import <Security/SecKey.h>
#import "NSString+MSIDExtensions.h"
#import "MSIDLogger+Internal.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDKeyOperationUtil.h"

@implementation MSIDJWTHelper

+ (NSString *)createSignedJWTforHeader:(NSDictionary *)header
                              payload:(NSDictionary *)payload
                           signingKey:(SecKeyRef)signingKey
{
    NSString *headerJSON = [self JSONFromDictionary:header];
    NSString *payloadJSON = [self JSONFromDictionary:payload];
    NSString *signingInput = [NSString stringWithFormat:@"%@.%@", [headerJSON msidBase64UrlEncode], [payloadJSON msidBase64UrlEncode]];
    NSData *signedData = [self sign:signingKey
                               data:[signingInput dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *signedEncodedDataString = [NSString msidBase64UrlEncodedStringFromData:signedData];

    return [NSString stringWithFormat:@"%@.%@", signingInput, signedEncodedDataString];
}

+ (NSData *)sign:(SecKeyRef)privateKey
            data:(NSData *)plainData
{
    SecKeyAlgorithm alg = kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256;
    NSString *signingAlg = [[MSIDKeyOperationUtil sharedInstance] getJwtAlgorithmForKey:privateKey context:nil error:nil];
    if (signingAlg == MSID_JWT_ALG_ES256)
    {
        alg = kSecKeyAlgorithmECDSASignatureMessageX962SHA256;
    }
    return [[MSIDKeyOperationUtil sharedInstance] getSignatureForDataWithKey:plainData privateKey:privateKey signingAlgorithm:alg context:nil error:nil];
}

+ (NSString *)JSONFromDictionary:(NSDictionary *)dictionary
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Got an error code: %ld error: %@", (long)error.code, MSID_PII_LOG_MASKABLE(error));

        return nil;
    }

    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return json;
}

@end
