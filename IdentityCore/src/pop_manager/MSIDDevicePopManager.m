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

#import "MSIDDevicePopManager.h"
#import "MSIDConstants.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJWTHelper.h"
#import "MSIDAssymetricKeyGeneratorFactory.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDAssymetricKeyPair.h"

static NSString *s_jwkTemplate = nil;
static NSString *s_kidTemplate = nil;

@interface MSIDDevicePopManager()

@property (nonatomic) MSIDCacheConfig *cacheConfig;
@property (nonatomic) id<MSIDAssymetricKeyGenerating> keyGeneratorFactory;
@property (nonatomic) NSString *requestConfirmation;
@property (nonatomic) NSString *kid;
@property (nonatomic) MSIDAssymetricKeyLookupAttributes *keyPairAttributes;
@property (nonatomic) MSIDAssymetricKeyPair *keyPair;
@property (nonatomic) NSString *keyExponent;
@property (nonatomic) NSString *keyModulus;

@end

@implementation MSIDDevicePopManager

+ (void)initialize
{
    if (self == [MSIDDevicePopManager self])
    {
        s_jwkTemplate = @"{\"e\":\"%@\",\"kty\":\"RSA\",\"n\":\"%@\"}";
        s_kidTemplate = @"{\"kid\":\"%@\"}";
    }
}

- (instancetype)initWithCacheConfig:(MSIDCacheConfig *)cacheConfig
                  keyPairAttributes:(MSIDAssymetricKeyLookupAttributes *)keyPairAttributes
{
    self = [super init];
    if (self)
    {
        _cacheConfig = cacheConfig;
        _keyGeneratorFactory = [MSIDAssymetricKeyGeneratorFactory defaultKeyGeneratorWithCacheConfig:self.cacheConfig error:nil];
        _keyPairAttributes = keyPairAttributes;
    }
    
    return self;
}

 - (MSIDAssymetricKeyPair *)keyPair
{
    if (!_keyPair)
    {
        NSError *keyPairError = nil;
        _keyPair = [self.keyGeneratorFactory readOrGenerateKeyPairForAttributes:self.keyPairAttributes error:&keyPairError];
        if (!_keyPair)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError,nil, @"Failed to generate key pair, error: %@", MSID_PII_LOG_MASKABLE(keyPairError));
        }
    }
    
    return _keyPair;
}

/// <summary>
/// Example JWK Thumbprint Computation
/// </summary>
/// <remarks>
/// This SDK will use RFC7638
/// See https://tools.ietf.org/html/rfc7638 Section3.1
/// </remarks>
- (NSString *)requestConfirmation
{
    if (!_requestConfirmation)
    {
        NSString *kid = [NSString stringWithFormat:s_kidTemplate, self.kid];
        if (!_kid)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError,nil, @"Failed to create req_cnf from kid");
            return nil;
        }
        
        NSData *kidData = [kid dataUsingEncoding:NSUTF8StringEncoding];
        _requestConfirmation = [kidData msidBase64UrlEncodedString];
    }
    
    return _requestConfirmation;
}

- (NSString *)kid
{
    if (!_kid)
    {
        _kid = [self generateKidFromModulus:self.keyModulus exponent:self.keyExponent];
    }
    
    return _kid;
}

- (NSString *)keyExponent
{
    if (!_keyExponent)
    {
        _keyExponent = self.keyPair.keyExponent;
    }
    
    return _keyExponent;
}

- (NSString *)keyModulus
{
    if (!_keyModulus)
    {
        _keyModulus = self.keyPair.keyModulus;
    }
    
    return _keyModulus;
}

- (NSString *)generateKidFromModulus:(NSString *)exponent exponent:(NSString *)modulus
{
    NSString* jwk = [NSString stringWithFormat:s_jwkTemplate, exponent, modulus];
    NSData *jwkData = [jwk dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hashedData = [jwkData msidSHA256];
    return [hashedData msidBase64UrlEncodedString];
}

- (NSString *)createSignedAccessToken:(NSString *)accessToken
                           httpMethod:(NSString *)httpMethod
                           requestUrl:(NSString *)requestUrl
                                nonce:(NSString *)nonce
                                error:(NSError *__autoreleasing * _Nullable)error
{
    NSString *kid = self.kid;
    
    if (!kid)
    {
        [self logAndFillError:@"Failed to create signed access token, unable to generate kid." error:error];
        return nil;
    }
    
    NSURL *url = [NSURL URLWithString:requestUrl];
    if (!url)
    {
        [self logAndFillError:[NSString stringWithFormat:@"Failed to create signed access token, invalid request url : %@.",requestUrl] error:error];
        return nil;
    }
    
    NSString *host = url.host;
    if (!host)
    {
        [self logAndFillError:[NSString stringWithFormat:@"Failed to create signed access token, invalid request url : %@.",requestUrl] error:error];
        return nil;
    }
    
    NSString *path = url.path;
    if (!path)
    {
        [self logAndFillError:[NSString stringWithFormat:@"Failed to create signed access token, invalid request url : %@.",requestUrl] error:error];
        return nil;
    }
    
    if (!self.keyModulus)
    {
        [self logAndFillError:@"Failed to create signed access token, unable to read public key modulus." error:error];
        return nil;
    }
    
    if (!self.keyExponent)
    {
        [self logAndFillError:@"Failed to create signed access token, unable to read public key exponent." error:error];
        return nil;
    }
    
    NSDictionary *header = @{
                             @"alg" : @"RS256",
                             @"typ" : @"JWT",
                             @"kid" : kid
                             };
    
    NSDictionary *payload = @{
                              @"at" : accessToken,
                              @"cnf": @{
                                      @"jwk":@{
                                          @"kty" : @"RSA",
                                          @"n" : self.keyModulus,
                                          @"e" : self.keyExponent
                                      }
                              },
                              @"ts" : [NSString stringWithFormat:@"%lu", (long)[[NSDate date] timeIntervalSince1970]],
                              @"m" : httpMethod,
                              @"u" : host,
                              @"p" : path,
                              @"nonce" : nonce,
                              };
    
    SecKeyRef privateKeyRef = self.keyPair.privateKeyRef;
    NSString *signedJwtHeader = [MSIDJWTHelper createSignedJWTforHeader:header payload:payload signingKey:privateKeyRef];
    return signedJwtHeader;
}

- (void)logAndFillError:(NSString *)description error:(NSError **)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", description);
    
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, description, nil, nil, nil, nil, nil, NO);
    }
}

@end
