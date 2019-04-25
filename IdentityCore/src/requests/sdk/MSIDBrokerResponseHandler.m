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

#import "MSIDBrokerResponseHandler.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTokenResult.h"
#import "MSIDConstants.h"
#import "MSIDBrokerResponse.h"
#import "MSIDBrokerCryptoProvider.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDCacheAccessor.h"
#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#endif
#import "MSIDTokenResponseValidator.h"
#import "MSIDTelemetryBrokerEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDBrokerResponseHandler()

@property (nonatomic, readwrite) MSIDOauth2Factory *oauthFactory;
@property (nonatomic, readwrite) MSIDBrokerCryptoProvider *brokerCryptoProvider;
@property (nonatomic, readwrite) MSIDTokenResponseValidator *tokenResponseValidator;
@property (nonatomic, readwrite) id<MSIDCacheAccessor> tokenCache;

@end

@implementation MSIDBrokerResponseHandler

#pragma mark - Init

- (instancetype)initWithOauthFactory:(MSIDOauth2Factory *)factory
              tokenResponseValidator:(MSIDTokenResponseValidator *)responseValidator
{
    self = [super init];

    if (self)
    {
        _oauthFactory = factory;
        _tokenResponseValidator = responseValidator;
    }

    return self;
}

#pragma mark - Broker response

- (MSIDTokenResult *)handleBrokerResponseWithURL:(NSURL *)response error:(NSError **)error
{
    MSID_LOG_INFO(nil, @"Handling broker response.");
    
    // Verify resume dictionary
    NSDictionary *resumeState = [self verifyResumeStateDicrionary:response error:error];

    if (!resumeState)
    {
        return nil;
    }

    NSUUID *correlationId = [[NSUUID alloc] initWithUUIDString:[resumeState objectForKey:@"correlation_id"]];
    NSString *keychainGroup = resumeState[@"keychain_group"];
    NSString *oidcScope = resumeState[@"oidc_scope"];

    // Initialize broker key and cache datasource
    MSIDBrokerKeyProvider *brokerKeyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:keychainGroup];

    NSError *brokerKeyError = nil;
    NSData *brokerKey = [brokerKeyProvider brokerKeyWithError:&brokerKeyError];

    if (!brokerKey)
    {
        NSString *descr = [NSString stringWithFormat:@"Couldn't find broker key with error %@", brokerKeyError];
        MSIDFillAndLogError(error, MSIDErrorBrokerKeyNotFound, descr, correlationId);
        return nil;
    }

    self.brokerCryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:brokerKey];

    // NSURLComponents resolves some URLs which can't get resolved by NSURL
    NSURLComponents *components = [NSURLComponents componentsWithURL:response resolvingAgainstBaseURL:NO];
    NSString *qpString = [components percentEncodedQuery];
    //expect to either response or error and description, AND correlation_id AND hash.
    NSDictionary *queryParamsMap =  [NSDictionary msidDictionaryFromWWWFormURLEncodedString:qpString];

    NSError *cacheError = nil;
    self.tokenCache = [self cacheAccessorWithKeychainGroup:keychainGroup error:&cacheError];

    if (!self.tokenCache)
    {
        if (error) *error = cacheError;
        return nil;
    }

    NSError *brokerError = nil;
    MSIDBrokerResponse *brokerResponse = [self brokerResponseFromEncryptedQueryParams:queryParamsMap
                                                                            oidcScope:oidcScope
                                                                        correlationId:correlationId
                                                                                error:&brokerError];

    if (!brokerResponse)
    {
        if (error) *error = brokerError;
        return nil;
    }

    return [self.tokenResponseValidator validateAndSaveBrokerResponse:brokerResponse
                                                            oidcScope:oidcScope
                                                         oauthFactory:self.oauthFactory
                                                           tokenCache:self.tokenCache
                                                        correlationID:correlationId
                                                                error:error];
}

#pragma mark - Helpers

- (NSDictionary *)verifyResumeStateDicrionary:(NSURL *)response error:(NSError **)error
{
    if (!response)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Provided broker response is nil", nil);
        return nil;
    }

    NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];

    if (!resumeDictionary)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerNoResumeStateFound, @"No broker resume state found in NSUserDefaults", nil);
        return nil;
    }

    NSUUID *correlationId = [[NSUUID alloc] initWithUUIDString:[resumeDictionary objectForKey:@"correlation_id"]];
    NSString *redirectUri = [resumeDictionary objectForKey:@"redirect_uri"];

    if (!redirectUri)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerBadResumeStateFound, @"Resume state is missing the redirect uri!", correlationId);
        return nil;
    }

    NSString *keychainGroup = resumeDictionary[@"keychain_group"];

    if (!keychainGroup)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerBadResumeStateFound, @"Resume state is missing the keychain group!", correlationId);
        return nil;
    }

    // Check to make sure this response is coming from the redirect URI we're expecting.
    if (![[[response absoluteString] lowercaseString] hasPrefix:[redirectUri lowercaseString]])
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerMismatchedResumeState, @"URL not coming from the expected redirect URI!", correlationId);
        return nil;
    }

    return resumeDictionary;
}

#pragma mark - Abstract

- (MSIDBrokerResponse *)brokerResponseFromEncryptedQueryParams:(__unused NSDictionary *)encryptedParams
                                                     oidcScope:(__unused NSString *)oidcScope
                                                 correlationId:(__unused NSUUID *)correlationID
                                                         error:(__unused NSError **)error
{
    NSAssert(NO, @"Abstract method, implemented in subclasses");
    return nil;
}

- (id<MSIDCacheAccessor>)cacheAccessorWithKeychainGroup:(__unused NSString *)keychainGroup
                                                  error:(__unused NSError **)error
{
    NSAssert(NO, @"Abstract method, implemented in subclasses");
    return nil;
}

@end
