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

#import "MSIDClientCredentialHelper.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJWTHelper.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDAccessToken.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDAADAuthority.h"

@implementation MSIDClientCredentialHelper

+ (NSMutableDictionary<MSIDLegacyTokenCacheKey *, MSIDAccessToken *> *)accessTokenCache
{
    static dispatch_once_t once;
    static NSMutableDictionary<MSIDLegacyTokenCacheKey *, MSIDAccessToken *> *accessTokenCache = nil;
    
    dispatch_once(&once, ^{
        accessTokenCache = [NSMutableDictionary dictionary];
    });
    
    return accessTokenCache;
}

+ (void)getAccessTokenForAuthority:(NSString *)authority
                          resource:(NSString *)resource
                          clientId:(NSString *)clientId
                  clientCredential:(NSString *)clientCredential
                 completionHandler:(void (^)(NSString *, NSError *))completionHandler
{
    MSIDLegacyTokenCacheKey *cacheKey = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:[NSURL URLWithString:authority]
                                                                                  clientId:clientId
                                                                                  resource:resource
                                                                              legacyUserId:clientId];
    
    MSIDAccessToken *accessToken = self.accessTokenCache[cacheKey];
    
    if (accessToken && !accessToken.isExpired)
    {
        if (completionHandler)
        {
            completionHandler(accessToken.accessToken, nil);
        }
        
        return;
    }
    
    NSDictionary *postParams = @{@"client_id": clientId,
                                 @"grant_type": @"client_credentials",
                                 @"client_secret": clientCredential,
                                 @"resource": resource,
                                 };
    
    [self getAccessTokenForAuthority:authority
                            resource:resource
                            clientId:clientId
                      postParameters:postParams
                   completionHandler:completionHandler];
}

+ (void)getAccessTokenForAuthority:(NSString *)authorityString
                          resource:(NSString *)resource
                          clientId:(NSString *)clientId
                       certificate:(NSData *)certificateData
               certificatePassword:(NSString *)password
                 completionHandler:(void (^)(NSString *accessToken, NSError *error))completionHandler
{
    MSIDLegacyTokenCacheKey *cacheKey = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:[NSURL URLWithString:authorityString]
                                                                                  clientId:clientId
                                                                                  resource:resource
                                                                              legacyUserId:clientId];
    
    MSIDAccessToken *accessToken = self.accessTokenCache[cacheKey];
    
    if (accessToken && !accessToken.isExpired)
    {
        if (completionHandler)
        {
            completionHandler(accessToken.accessToken, nil);
        }
        
        return;
    }
    
    NSString *tokenEndpoint = [NSString stringWithFormat:@"%@/oauth2/token", authorityString];
    NSString *assertion = [self clientCertificateAssertionForAudience:tokenEndpoint
                                                             clientId:clientId
                                                      certificateData:certificateData
                                                             password:password];
    
    if (!assertion)
    {
        if (completionHandler)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Couldn't create assertion.", nil, nil, nil, nil, nil);
            completionHandler(nil, error);
        }
        
        return;
    }
    
    NSDictionary *postParams = @{@"client_id": clientId,
                                 @"grant_type": @"client_credentials",
                                 @"client_assertion_type": @"urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                                 @"resource": resource,
                                 @"client_assertion": assertion
                                 };
    
    [self getAccessTokenForAuthority:authorityString
                            resource:resource
                            clientId:clientId
                      postParameters:postParams
                   completionHandler:completionHandler];
}

+ (void)getAccessTokenForAuthority:(NSString *)authorityString
                          resource:(NSString *)resource
                          clientId:(NSString *)clientId
                    postParameters:(NSDictionary *)postParams
                 completionHandler:(void (^)(NSString *accessToken, NSError *error))completionHandler
{
    NSString *tokenEndpoint = [NSString stringWithFormat:@"%@/oauth2/token", authorityString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:tokenEndpoint]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    NSData *requestBody = [[postParams msidWWWFormURLEncode] dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:requestBody];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    [[session dataTaskWithRequest:request
                completionHandler:^(NSData * _Nullable data,
                                    NSURLResponse * _Nullable response, NSError * _Nullable error)
      {
          if (error)
          {
              if (completionHandler)
              {
                  completionHandler(nil, error);
              }
              return;
          }
          
          NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
          
          NSError *msidError = nil;
          MSIDAADV1TokenResponse *tokenResponse = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:result error:&msidError];
          
          if (msidError)
          {
              if (completionHandler)
              {
                  completionHandler(nil, msidError);
              }
              
              return;
          }
          
          __auto_type authorityUrl = [[NSURL alloc] initWithString:authorityString];
          __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
          
          MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                              redirectUri:nil
                                                                                 clientId:clientId
                                                                                   target:resource];
          
          MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
          
          BOOL checkResult = [factory verifyResponse:tokenResponse context:nil error:&msidError];
          
          if (!checkResult)
          {
              if (completionHandler)
              {
                  completionHandler(nil, msidError);
              }
          }
          
          MSIDAccessToken *accessToken = [factory accessTokenFromResponse:tokenResponse configuration:configuration];
          
          MSIDLegacyTokenCacheKey *cacheKey = [[MSIDLegacyTokenCacheKey alloc] initWithAuthority:[NSURL URLWithString:authorityString]
                                                                                        clientId:clientId
                                                                                        resource:resource
                                                                                    legacyUserId:clientId];
          
          self.accessTokenCache[cacheKey] = accessToken;
          
          if (completionHandler)
          {
              completionHandler(accessToken.accessToken, nil);
          }
          
      }] resume];
    
}

+ (NSString *)clientCertificateAssertionForAudience:(NSString *)audience
                                           clientId:(NSString *)clientID
                                    certificateData:(NSData *)certificateData
                                           password:(NSString *)password
{
    SecIdentityRef identity = [self createIdentityFromData:certificateData password:password];
    
    if (!identity)
    {
        NSLog(@"Couldn't load identity!");
        return nil;
    }
    
    SecKeyRef privateKey = nil;
    OSStatus result = SecIdentityCopyPrivateKey(identity, &privateKey);
    
    if (result != errSecSuccess)
    {
        NSLog(@"Couldn't copy private key");
        return nil;
    }
    
    SecCertificateRef certificate = nil;
    result = SecIdentityCopyCertificate(identity, &certificate);
    CFRelease(identity);
    
    if (result != errSecSuccess)
    {
        NSLog(@"Couldn't copy certificate");
        return nil;
    }
    
    CFDataRef data = SecCertificateCopyData(certificate);
    
    if (!data)
    {
        NSLog(@"Couldn't copy certificate data");
        return nil;
    }
    
    NSData *certData = (__bridge NSData *)(data);

    NSString *thumbprint = certData.msidSHA1.msidBase64UrlEncodedString;
    CFRelease(data);
    CFRelease(certificate);
    
    NSDictionary *header = @{@"alg" : @"RS256",
                             @"typ" : @"JWT",
                             @"x5t" : thumbprint};
    
    NSNumber *expDate = @((long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]);
    NSNumber *notBeforeDate = @((long)[[NSDate date] timeIntervalSince1970]);
    NSDictionary *payload = @{@"aud" : audience,
                              @"exp": expDate,
                              @"iss": clientID,
                              @"jti": [[NSUUID UUID] UUIDString],
                              @"nbf": notBeforeDate,
                              @"sub": clientID
                              };
    
    NSString *assertion = [MSIDJWTHelper createSignedJWTforHeader:header payload:payload signingKey:privateKey];
    CFRelease(privateKey);
    
    return assertion;
}

+ (SecIdentityRef)createIdentityFromData:(NSData *)data password:(NSString *)password
{
    CFArrayRef resultArray = nil;
    NSDictionary *options = @{(id)kSecImportExportPassphrase : password};
    OSStatus result = SecPKCS12Import((CFDataRef)data, (CFDictionaryRef)options, &resultArray);
    
    if (result != errSecSuccess)
    {
        return nil;
    }
    
    NSArray *items = CFBridgingRelease(resultArray);
    
    if ([items count])
    {
        NSDictionary *dictionary = items[0];
        return (SecIdentityRef)CFBridgingRetain((dictionary[(id)kSecImportItemIdentity]));
    }
    
    return nil;
}

@end

