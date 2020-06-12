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

static NSString *jwkTemplate = @"{\"e\":\"%@\",\"kty\":\"RSA\",\"n\":\"%@\"}";
static NSString *kidTemplate = @"{\"kid\":\"%@\"}";

@interface MSIDDevicePopManager()

@property id<MSIDAssymetricKeyGenerating> keyGeneratorFactory;
@property MSIDAssymetricKeyLookupAttributes *keyPairAttributes;
@property MSIDAssymetricKeyPair *keyPair;
@property NSData *publicKeyData;

@end

@implementation MSIDDevicePopManager

+ (MSIDDevicePopManager *)sharedInstance
{
    static dispatch_once_t once;
    static MSIDDevicePopManager *singleton = nil;
    
    dispatch_once(&once, ^{
        singleton = [[MSIDDevicePopManager alloc] init];
    });
    
    return singleton;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _keyGeneratorFactory = [MSIDAssymetricKeyGeneratorFactory defaultKeyGeneratorWithError:nil];
        
        NSString *privateKeyIdentifier = MSID_POP_TOKEN_PRIVATE_KEY;
        NSString *publicKeyIdentifier = MSID_POP_TOKEN_PUBLIC_KEY;
        
        MSIDAssymetricKeyLookupAttributes *attr = [MSIDAssymetricKeyLookupAttributes new];
        attr.privateKeyIdentifier = privateKeyIdentifier;
        attr.publicKeyIdentifier = publicKeyIdentifier;
        
        NSError *localError = nil;
        _keyPair = [self.keyGeneratorFactory readOrGenerateKeyPairForAttributes:attr error:&localError];
        
        if (!_keyPair)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to generate asymmetric key pair %@", localError);
            return nil;
        }
        
        _publicKeyData = [_keyPair getDataFromKeyRef:_keyPair.publicKeyRef];
        
        if (!_publicKeyData)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read public key data");
            return nil;
        }
    }
    
    return self;
}


- (NSString *)getPublicKeyJWK
{
    NSString* jwk = [NSString stringWithFormat:jwkTemplate,
                     [self.keyPair getKeyExponent:self.keyPair.publicKeyRef],
                     [self.keyPair getKeyModulus:self.keyPair.publicKeyRef]];
    
    NSData *jwkData = [jwk dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hashedData = [jwkData msidSHA256];
    NSString *base64EncodedJWK = [hashedData msidBase64UrlEncodedString];
    return base64EncodedJWK;
}

- (NSString *)getRequestConfirmation
{
    NSString *kid = [NSString stringWithFormat:kidTemplate, [self getPublicKeyJWK]];
    NSData *kidData = [kid dataUsingEncoding:NSUTF8StringEncoding];
    return [kidData msidBase64UrlEncodedString];
}

- (NSString *)createSignedAccessToken:(NSString *)accessToken
                           httpMethod:(NSString *)httpMethod
                           requestUrl:(NSString *)requestUrl
                                nonce:(NSString *)nonce
                                error:(NSError *__autoreleasing * _Nullable)error
{
    NSString *kid = [self getPublicKeyJWK];
    
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
