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

#import "MSIDUniversalCacheAccessor.h"
#import "MSIDTokenCacheKey+Default.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDAadAuthorityCache.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDTokenCacheKey+Default.h"
#import "MSIDJsonSerializer.h"
#import "MSIDCredential.h"
#import "MSIDUniversalContext.h"
#import "MSIDErrorCodes.h"
#import "MSIDCredentialWrapper.h"

@interface MSIDUniversalCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    
    MSIDJsonSerializer *_credentialSerializer;
}

@end

@implementation MSIDUniversalCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _credentialSerializer = [[MSIDJsonSerializer alloc] initWithClassName:MSIDCredentialWrapper.class];
    }
    
    return self;
}

#pragma mark - MSIDIStorageManager

- (MSIDReadCredentialsResponse *)readCredentials:(NSString *)correlationId
                                        uniqueId:(NSString *)uniqueId
                                     environment:(NSString *)environment
                                        clientId:(NSString *)clientId
                                           realm:(NSString *)realm
                                          target:(NSString *)target
                                            type:(MSIDCredentialType)type
{
    NSString *telemetryRequestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID *correlationIdUUID = [[NSUUID alloc] initWithUUIDString:correlationId];
    
    MSIDUniversalContext *context = [[MSIDUniversalContext alloc] initWithCorrelationId:correlationIdUUID
                                                                     telemetryRequestId:telemetryRequestId];
    
    NSError *error = nil;
    
    NSArray<MSIDCredential *> *credentials = [self credentialsWithUniqueId:uniqueId
                                                               environment:environment
                                                                  clientId:clientId
                                                                     realm:realm
                                                                    target:target
                                                                      type:type
                                                                     error:&error
                                                                   context:context];
    
    MSIDOperationStatus *status = nil;
    
    if (error)
    {
        status = [[MSIDOperationStatus alloc] initWithType:MSIDStatusTypeFailure
                                                      code:MSIDErrorCodesCacheReadError
                                      operationDescription:error.description
                                              platformCode:error.code
                                            platformDomain:error.domain];
    }
    else
    {
        // TODO: what should be value for description, domain and code for successful case?
        status = [[MSIDOperationStatus alloc] initWithType:MSIDStatusTypeSuccess
                                                      code:0
                                      operationDescription:@"Success"
                                              platformCode:0
                                            platformDomain:@""];
    }
    
    
    return [[MSIDReadCredentialsResponse alloc] initWithCredentials:credentials
                                                             status:status];
}

/**
 * write all. Envs etc do not have to match
 * correlation_id: required
 * creds: required
 */
- (MSIDOperationStatus *)writeCredentials:(NSString *)correlationId
                              credentials:(NSArray<MSIDCredential *> *)credentials
{
    NSString *telemetryRequestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID *correlationIdUUID = [[NSUUID alloc] initWithUUIDString:correlationId];
    
    MSIDUniversalContext *context = [[MSIDUniversalContext alloc] initWithCorrelationId:correlationIdUUID
                                                                     telemetryRequestId:telemetryRequestId];
    
    NSError *error = nil;
    BOOL result = [self saveCredentials:credentials error:&error context:context];
    
    if (!result)
    {
        return [[MSIDOperationStatus alloc] initWithType:MSIDStatusTypeFailure
                                                    code:MSIDErrorCodesCacheReadError
                                      operationDescription:error.description
                                              platformCode:error.code
                                            platformDomain:error.domain];
    }
    else
    {
        return [[MSIDOperationStatus alloc] initWithType:MSIDStatusTypeSuccess
                                                    code:0
                                    operationDescription:@"Success"
                                            platformCode:0
                                          platformDomain:@""];
    }
}

/**matches read_credentials */
- (MSIDOperationStatus *)deleteCredentials:(NSString *)correlationId
                                  uniqueId:(NSString *)uniqueId
                               environment:(NSString *)environment
                                  clientId:(NSString *)clientId
                                     realm:(NSString *)realm
                                    target:(NSString *)target
                                      type:(MSIDCredentialType)type
{
    return nil;
}

- (MSIDReadAccountsResponse *)readAllAccounts:(NSString *)correlationId
{
    return nil;
}

- (MSIDReadAccountResponse *)readAccount:(NSString *)correlationId
                                uniqueId:(NSString *)uniqueId
                             environment:(NSString *)environment
                                   realm:(NSString *)realm
{
    return nil;
}

- (MSIDOperationStatus *)writeAccount:(NSString *)correlationId
                              account:(MSIDAccount *)account
{
    return nil;
}

/** When we remove an account we need to also remove its credentials */
- (MSIDOperationStatus *)deleteAccount:(NSString *)correlationId
                              uniqueId:(NSString *)uniqueId
                           environment:(NSString *)environment
                                 realm:(NSString *)realm
{
    return nil;
}

- (MSIDOperationStatus *)deleteAllAccounts:(NSString *)correlationId
{
    return nil;
}

#pragma mark - Helpers

- (NSArray<MSIDCredential *> *)credentialsWithUniqueId:(NSString *)uniqueId // Required
                                           environment:(NSString *)environment // Required
                                              clientId:(NSString *)clientId // Required
                                                 realm:(NSString *)realm // Can be empty
                                                target:(NSString *)target // Can be empty
                                                  type:(MSIDCredentialType)type // Required, bitmask
                                                 error:(NSError **)error
                                               context:(id<MSIDRequestContext>)context
{
    NSURL *authority = [NSURL urlWithEnvironment:environment andTenant:realm];
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    NSMutableArray *firstResults = [NSMutableArray array];
    
    // First filter out by uniqueId, environment and target
    for (NSURL *alias in aliases)
    {
        // Because C++ will be passing all nil values as empty strings, we need to replace empty string with nil :(
        NSString *keyTarget = [NSString msidIsStringNilOrBlank:target] ? nil : target;
        
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAllCredentialWithUniqueUserId:uniqueId
                                                                            environment:alias.msidHostWithPortIfNecessary
                                                                                 target:keyTarget];
        
        if (!key)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to create token cache key", nil, nil, nil, context.correlationId, nil);
            }
            
            return nil;
        }
        
        NSError *cacheError = nil;
        
        NSArray *tokens = [_dataSource itemsWithKey:key serializer:_credentialSerializer context:nil error:&cacheError];
        
        if (cacheError)
        {
            if (error)
            {
                *error = cacheError;
            }
            
            return nil;
        }
        
        [firstResults addObjectsFromArray:tokens];
    }
    
    NSMutableArray<MSIDCredential *> *filteredCredentials = [NSMutableArray array];
    
    // Now filter out by additional properties specified
    for (MSIDCredentialWrapper *credentialWrapper in firstResults)
    {
        if ((type & credentialWrapper.credential.credentialType) // Check that type is one of the types specified
            && [credentialWrapper.credential.clientId isEqualToString:clientId] // Check that clientId is matching
            && (!realm || [credentialWrapper.credential.realm isEqualToString:realm])) // Check that realm is matching if specified
        {
            [filteredCredentials addObject:credentialWrapper.credential];
        }
    }
        
    return filteredCredentials;
}

- (BOOL)saveCredentials:(NSArray<MSIDCredential *> *)credentials
                  error:(NSError **)error
                context:(id<MSIDRequestContext>)context
{
    for (MSIDCredential *credential in credentials)
    {
        NSURL *authority = [NSURL urlWithEnvironment:credential.environment andTenant:credential.realm];
        NSURL *newAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:authority context:context];
        
        MSIDTokenType tokenType = [self tokenTypeFromCredentialType:credential.credentialType];
        
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForCredentialWithUniqueUserId:credential.uniqueId
                                                                         environment:newAuthority.msidHostWithPortIfNecessary
                                                                            clientId:credential.clientId
                                                                               realm:credential.realm
                                                                              target:credential.target
                                                                           tokenType:tokenType];
        
        MSIDCredentialWrapper *credentialWrapper = [[MSIDCredentialWrapper alloc] initWithCredential:credential];
        
        BOOL result = [_dataSource setItem:credentialWrapper
                                       key:key
                                serializer:_credentialSerializer
                                   context:context
                                     error:error];
        
        if (!result)
        {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Token type

- (MSIDTokenType)tokenTypeFromCredentialType:(MSIDCredentialType)credentialType
{
    switch (credentialType) {
        case MSIDCredentialTypeOAuthAccessToken:
            return MSIDTokenTypeAccessToken;
        
        case MSIDCredentialTypeOAuthRefreshToken:
            return MSIDTokenTypeRefreshToken;
            
        case MSIDCredentialTypeOIDCIdTokenUnsigned:
        case MSIDCredentialTypeOIDCIdToken:
            return MSIDTokenTypeIDToken;
            
        case MSIDCredentialTypePassword:
            return MSIDTokenTypeOther;
            
        default:
            return MSIDTokenTypeOther;
    }
}

@end
