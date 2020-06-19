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
#import "MSIDDefaultTokenCacheAccessor.h"

static NSString *jwkTemplate = @"{\"e\":\"%@\",\"kty\":\"RSA\",\"n\":\"%@\"}";
static NSString *kidTemplate = @"{\"kid\":\"%@\"}";

@interface MSIDDevicePopManager()

@property (nonatomic) MSIDCacheConfig *cacheConfig;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) id<MSIDAssymetricKeyGenerating> keyGeneratorFactory;
@property (nonatomic) MSIDAssymetricKeyLookupAttributes *keyPairAttributes;
@property (nonatomic) MSIDAssymetricKeyPair *keyPair;
@property (nonatomic) NSString *requestConfirmation;
@property (nonatomic) NSString *kid;

@end

@implementation MSIDDevicePopManager

- (instancetype)initWithCacheConfig:(MSIDCacheConfig *)cacheConfig cache:(MSIDDefaultTokenCacheAccessor *)tokenCache
{
    self = [super init];
    if (self)
    {
        _cacheConfig = cacheConfig;
        _tokenCache = tokenCache;
    }
    
    return self;
}

 - (id<MSIDAssymetricKeyGenerating>)keyGeneratorFactory
{
    if (!_keyGeneratorFactory)
    {
        _keyGeneratorFactory = [MSIDAssymetricKeyGeneratorFactory defaultKeyGeneratorWithCacheConfig:self.cacheConfig error:nil];
    }
    
    return _keyGeneratorFactory;
}

 - (MSIDAssymetricKeyLookupAttributes *)keyPairAttributes
{
    if (!_keyPairAttributes)
    {
        _keyPairAttributes = [MSIDAssymetricKeyLookupAttributes new];
        NSString *privateKeyIdentifier = MSID_POP_TOKEN_PRIVATE_KEY;
        NSString *publicKeyIdentifier = MSID_POP_TOKEN_PUBLIC_KEY;
        _keyPairAttributes.privateKeyIdentifier = privateKeyIdentifier;
        _keyPairAttributes.publicKeyIdentifier = publicKeyIdentifier;
    }
    
    return _keyPairAttributes;
}

 - (MSIDAssymetricKeyPair *)keyPair
{
    if (!_keyPair)
    {
        _keyPair = [self.keyGeneratorFactory readOrGenerateKeyPairForAttributes:self.keyPairAttributes error:nil];
    }
    
    return _keyPair;
}

- (NSString *)requestConfirmation
{
    if (!_requestConfirmation)
    {
        NSString *kid = [NSString stringWithFormat:kidTemplate, self.kid];
        NSData *kidData = [kid dataUsingEncoding:NSUTF8StringEncoding];
        _requestConfirmation = [kidData msidBase64UrlEncodedString];
    }
    
    return _requestConfirmation;
}

- (NSString *)kid
{
    if (!_kid)
    {
        NSString* jwk = [NSString stringWithFormat:jwkTemplate,
                         [self.keyPair getKeyExponent:self.keyPair.publicKeyRef],
                         [self.keyPair getKeyModulus:self.keyPair.publicKeyRef]];
        
        NSData *jwkData = [jwk dataUsingEncoding:NSUTF8StringEncoding];
        NSData *hashedData = [jwkData msidSHA256];
        _kid = [hashedData msidBase64UrlEncodedString];
    }

    return _kid;
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
    
    NSString *publicKeyModulus = [self.keyPair getKeyModulus:self.keyPair.publicKeyRef];
    if (!publicKeyModulus)
    {
        [self logAndFillError:@"Failed to create signed access token, unable to read public key modulus." error:error];
        return nil;
    }
    
    NSString *publicKeyExponent = [self.keyPair getKeyExponent:self.keyPair.publicKeyRef];
    if (!publicKeyExponent)
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
                                          @"n" : publicKeyModulus,
                                          @"e" : publicKeyExponent
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
