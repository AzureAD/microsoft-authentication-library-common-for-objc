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

@interface MSIDBrokerResponseHandler()

@property (nonatomic, readwrite) MSIDOauth2Factory *oauthFactory;
@property (nonatomic, readwrite) MSIDBrokerKeyProvider *brokerKeyProvider;

@end

@implementation MSIDBrokerResponseHandler

#pragma mark - Init

- (instancetype)initWithOauthFactory:(MSIDOauth2Factory *)factory
{
    self = [super init];

    if (self)
    {
        _oauthFactory = factory;
    }

    return self;
}

#pragma mark - Broker response

- (MSIDTokenResult *)handleBrokerResponseWithURL:(NSURL *)response error:(NSError **)error
{
#if TARGET_OS_IPHONE
    if (![self verifyResponseWithResumeDictionary:response error:error])
    {
        return nil;
    }

    // NSURLComponents resolves some URLs which can't get resolved by NSURL
    NSURLComponents *components = [NSURLComponents componentsWithURL:response resolvingAgainstBaseURL:NO];
    NSString *qpString = [components percentEncodedQuery];
    //expect to either response or error and description, AND correlation_id AND hash.
    NSDictionary *queryParamsMap =  [NSDictionary msidDictionaryFromWWWFormURLEncodedString:qpString];
    return [self processAndSaveBrokerResultWithQueryParams:queryParamsMap error:error];
#else
    MSIDFillAndLogError(error, MSIDErrorInternal, @"Broker response handling is not supported on macOS", nil);
    return nil;
#endif
}

#pragma mark - Helpers

- (BOOL)verifyResponseWithResumeDictionary:(NSURL *)response error:(NSError **)error
{
    if (!response)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Provided broker response is nil", nil);
        return NO;
    }

    NSDictionary *resumeDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];

    if (!resumeDictionary)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerNoResumeStateFound, @"No broker resume state found in NSUserDefaults", nil);
        return NO;
    }

    NSUUID *correlationId = [[NSUUID alloc] initWithUUIDString:[resumeDictionary objectForKey:@"correlation_id"]];
    NSString *redirectUri = [resumeDictionary objectForKey:@"redirect_uri"];

    if (!redirectUri)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerBadResumeStateFound, @"Resume state is missing the redirect uri!", correlationId);
        return NO;
    }

    NSString *keychainGroup = resumeDictionary[@"keychain_group"];

    if (!keychainGroup)
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerBadResumeStateFound, @"Resume state is missing the keychain group!", correlationId);
        return NO;
    }

    // Check to make sure this response is coming from the redirect URI we're expecting.
    if (![[[response absoluteString] lowercaseString] hasPrefix:[redirectUri lowercaseString]])
    {
        MSIDFillAndLogError(error, MSIDErrorBrokerMismatchedResumeState, @"URL not coming from the expected redirect URI!", correlationId);
        return NO;
    }

    // Initialize broker key
    self.brokerKeyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:keychainGroup];

    return YES;
}

#pragma mark - Abstract

- (MSIDTokenResult *)processAndSaveBrokerResultWithQueryParams:(NSDictionary *)encryptedParams
                                                         error:(NSError **)error
{
    NSAssert(NO, @"Abstract method, implemented in subclasses");
    return nil;
}

- (NSDictionary *)responseDictionaryFromEncryptedQueryParams:(NSDictionary *)encryptedParams
                                               correlationId:(NSUUID *)correlationID
                                                       error:(NSError **)error
{
    NSError *brokerKeyError = nil;
    NSData *brokerKey = [self.brokerKeyProvider brokerKeyWithError:&brokerKeyError];

    if (!brokerKey)
    {
        NSString *descr = [NSString stringWithFormat:@"Couldn't find broker key with error %@", brokerKeyError];
        MSIDFillAndLogError(error, MSIDErrorBrokerKeyNotFound, descr, correlationID);
        return nil;
    }

    MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:brokerKey];

    NSDictionary *decryptedResponse = [cryptoProvider decryptBrokerResponse:encryptedParams
                                                              correlationId:correlationID
                                                                      error:error];

    return decryptedResponse;
}

@end
