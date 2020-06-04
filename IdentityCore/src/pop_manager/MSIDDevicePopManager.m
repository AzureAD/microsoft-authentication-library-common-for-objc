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
    }
    
    return self;
}

- (NSString *)getPublicKeyExp:(NSData *)publicKeyBits
{
    NSData* pk = [publicKeyBits copy];
    if (pk == NULL) return NULL;
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:pk at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:pk at:&iterator];
    iterator += mod_size;
    
    iterator++; // TYPE - bit stream exp
    int exp_size = [self derEncodingGetSizeFrom:pk at:&iterator];
    
    return [[pk subdataWithRange:NSMakeRange(iterator, exp_size)] base64EncodedStringWithOptions:0];
}

- (NSString *)getPublicKeyMod:(NSData *)publicKeyBits
{
    NSData* pk = [publicKeyBits copy];
    if (pk == NULL) return NULL;
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:pk at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:pk at:&iterator];
    NSData* subData=[pk subdataWithRange:NSMakeRange(iterator, mod_size)];
    NSString *mod = [[subData subdataWithRange:NSMakeRange(1, subData.length-1)] base64EncodedStringWithOptions:0];
    return mod;
}

- (int)derEncodingGetSizeFrom:(NSData *)buf at:(int *)iterator
{
    const uint8_t* data = [buf bytes];
    int itr = *iterator;
    int num_bytes = 1;
    int ret = 0;
    
    if (data[itr] > 0x80) {
        num_bytes = data[itr] - 0x80;
        itr++;
    }
    
    for (int i = 0 ; i < num_bytes; i++)
        ret = (ret * 0x100) + data[itr + i];
    
    *iterator = itr + num_bytes;
    return ret;
}

- (NSString *)getPublicKeyJWK
{
    NSString* jwk = [NSString stringWithFormat:jwkTemplate,
                     [self getPublicKeyExp:self.keyPair.publicKeyBits],
                     [self getPublicKeyMod:self.keyPair.publicKeyBits]];
    
    NSData *jwkData = [jwk dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hashedData = [jwkData msidSHA256];
    NSString *base64EncodedJWK = [hashedData msidBase64UrlEncodedString];
    return base64EncodedJWK;
}

- (NSString *)getRequestConfirmation:(NSError **)error
{
    NSString *kid = [NSString stringWithFormat:kidTemplate, [self getPublicKeyJWK]];
    NSData *kidData = [kid dataUsingEncoding:NSUTF8StringEncoding];
    return [kidData msidBase64UrlEncodedString];
}

- (NSString *)createSignedAccessToken:(NSString *)accessToken
                           httpMethod:(NSString *)httpMethod
                           requestUrl:(NSString *)requestUrl
                                nonce:(NSString *)nonce
                                error:(NSError **)error
{
    NSData *publicKeyBits = self.keyPair.publicKeyBits;
    NSString *kid = [self getPublicKeyJWK];
    
    if (!kid)
    {
        if (error)
        {
           NSString *errorDescription = [NSString stringWithFormat:@"Error generating kid from public key bits."];
           *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        }
        
        return nil;
    }
    
    NSURL *url = [NSURL URLWithString:requestUrl];
    if (!url)
    {
        if (error)
        {
          NSString *errorDescription = [NSString stringWithFormat:@"Invalid request url %@", requestUrl];
          *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
            
        }
               
        return nil;
    }
    
    NSString *host = url.host;
    NSString *path = url.path;
    
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
                                          @"n" : [self getPublicKeyMod:publicKeyBits],
                                          @"e" : [self getPublicKeyExp:publicKeyBits]
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

+ (NSString*)decryptJWT:(NSData *)jwtData
          decrpytionKey:(SecKeyRef)decrpytionKey
{
#if TARGET_OS_IPHONE
    size_t cipherBufferSize = SecKeyGetBlockSize(decrpytionKey);
#endif // TARGET_OS_IPHONE
    size_t keyBufferSize = [jwtData length];
    
    NSMutableData *bits = [NSMutableData dataWithLength:keyBufferSize];
    OSStatus status = errSecAuthFailed;
#if TARGET_OS_IPHONE
    status = SecKeyDecrypt(decrpytionKey,
                           kSecPaddingPKCS1,
                           (const uint8_t *) [jwtData bytes],
                           cipherBufferSize,
                           [bits mutableBytes],
                           &keyBufferSize);
#else // !TARGET_OS_IPHONE
    (void)decrpytionKey;
    // TODO: SecKeyDecrypt is not available on OS X
#endif // TARGET_OS_IPHONE
    if(status != errSecSuccess)
    {
        return nil;
    }
    
    [bits setLength:keyBufferSize];
    return [[NSString alloc] initWithData:bits encoding:NSUTF8StringEncoding];
}

@end
