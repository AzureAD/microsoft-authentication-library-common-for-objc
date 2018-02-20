// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from cache.djinni

#import "MSIDOperationStatus.h"


@implementation MSIDOperationStatus

- (nonnull instancetype)initWithType:(MSIDStatusType)type
                                code:(int64_t)code
                operationDescription:(nonnull NSString *)operationDescription
                        platformCode:(int64_t)platformCode
                      platformDomain:(nonnull NSString *)platformDomain
{
    if (self = [super init]) {
        _type = type;
        _code = code;
        _operationDescription = [operationDescription copy];
        _platformCode = platformCode;
        _platformDomain = [platformDomain copy];
    }
    return self;
}

+ (nonnull instancetype)operationStatusWithType:(MSIDStatusType)type
                                           code:(int64_t)code
                           operationDescription:(nonnull NSString *)operationDescription
                                   platformCode:(int64_t)platformCode
                                 platformDomain:(nonnull NSString *)platformDomain
{
    return [[self alloc] initWithType:type
                                 code:code
                 operationDescription:operationDescription
                         platformCode:platformCode
                       platformDomain:platformDomain];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p type:%@ code:%@ operationDescription:%@ platformCode:%@ platformDomain:%@>", self.class, (void *)self, @(self.type), @(self.code), self.operationDescription, @(self.platformCode), self.platformDomain];
}

@end
