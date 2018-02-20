// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from cache.djinni

#import "MSIDReadAccountsResponse.h"


@implementation MSIDReadAccountsResponse

- (nonnull instancetype)initWithAccount:(nonnull NSArray<MSIDAccount *> *)account
                                 status:(nonnull MSIDOperationStatus *)status
{
    if (self = [super init]) {
        _account = [account copy];
        _status = status;
    }
    return self;
}

+ (nonnull instancetype)readAccountsResponseWithAccount:(nonnull NSArray<MSIDAccount *> *)account
                                                 status:(nonnull MSIDOperationStatus *)status
{
    return [[self alloc] initWithAccount:account
                                  status:status];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p account:%@ status:%@>", self.class, (void *)self, self.account, self.status];
}

@end
