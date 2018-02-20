// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from cache.djinni

#import "MSIDAccount.h"
#import "MSIDCredential.h"
#import "MSIDCredentialType.h"
#import "MSIDOperationStatus.h"
#import "MSIDReadAccountResponse.h"
#import "MSIDReadAccountsResponse.h"
#import "MSIDReadCredentialsResponse.h"
#import <Foundation/Foundation.h>


/** This interface will be implemented in Java and ObjC and can be called from C++. */
@protocol MSIDIStorageManager

/**
 * Gets all credentials which match the parameters
 * correlation_id: required
 * unique_id: required
 * environment: required
 * client_id: required
 * realm: optional. Null means "match all"
 * target: optional. Null means "match all"
 * type: required. It's a bitmap. The API should return all types for which the bits are set.
 */
- (nonnull MSIDReadCredentialsResponse *)readCredentials:(nonnull NSString *)correlationId
                                                uniqueId:(nonnull NSString *)uniqueId
                                             environment:(nonnull NSString *)environment
                                                clientId:(nonnull NSString *)clientId
                                                   realm:(nonnull NSString *)realm
                                                  target:(nonnull NSString *)target
                                                    type:(MSIDCredentialType)type;

/**
 * write all. Envs etc do not have to match
 * correlation_id: required
 * creds: required
 */
- (nonnull MSIDOperationStatus *)writeCredentials:(nonnull NSString *)correlationId
                                      credentials:(nonnull NSArray<MSIDCredential *> *)credentials;

/**matches read_credentials */
- (nonnull MSIDOperationStatus *)deleteCredentials:(nonnull NSString *)correlationId
                                          uniqueId:(nonnull NSString *)uniqueId
                                       environment:(nonnull NSString *)environment
                                          clientId:(nonnull NSString *)clientId
                                             realm:(nonnull NSString *)realm
                                            target:(nonnull NSString *)target
                                              type:(MSIDCredentialType)type;

- (nonnull MSIDReadAccountsResponse *)readAllAccounts:(nonnull NSString *)correlationId;

- (nonnull MSIDReadAccountResponse *)readAccount:(nonnull NSString *)correlationId
                                        uniqueId:(nonnull NSString *)uniqueId
                                     environment:(nonnull NSString *)environment
                                           realm:(nonnull NSString *)realm;

- (nonnull MSIDOperationStatus *)writeAccount:(nonnull NSString *)correlationId
                                      account:(nonnull MSIDAccount *)account;

/** When we remove an account we need to also remove its credentials */
- (nonnull MSIDOperationStatus *)deleteAccount:(nonnull NSString *)correlationId
                                      uniqueId:(nonnull NSString *)uniqueId
                                   environment:(nonnull NSString *)environment
                                         realm:(nonnull NSString *)realm;

- (nonnull MSIDOperationStatus *)deleteAllAccounts:(nonnull NSString *)correlationId;

@end
