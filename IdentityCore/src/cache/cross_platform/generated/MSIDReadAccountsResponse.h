// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from cache.djinni

#import "MSIDAccount.h"
#import "MSIDOperationStatus.h"
#import <Foundation/Foundation.h>

@interface MSIDReadAccountsResponse : NSObject
- (nonnull instancetype)initWithAccount:(nonnull NSArray<MSIDAccount *> *)account
                                 status:(nonnull MSIDOperationStatus *)status;
+ (nonnull instancetype)readAccountsResponseWithAccount:(nonnull NSArray<MSIDAccount *> *)account
                                                 status:(nonnull MSIDOperationStatus *)status;

@property (nonatomic, readonly, nonnull) NSArray<MSIDAccount *> * account;

@property (nonatomic, readonly, nonnull) MSIDOperationStatus * status;

@end
