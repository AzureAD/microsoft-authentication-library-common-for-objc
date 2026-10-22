//
//  MSIDAutomationReturnedTokensResult.m
//  IdentityCore
//
//  Created by Ameya Patil on 12/18/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//
#import "MSIDAutomationReturnedTokensResult.h"

@implementation MSIDAutomationReturnedTokensResult

- (instancetype)initWithAction:(NSString *)actionId
                        tokens:(NSArray<MSIDBaseToken *> *)tokens
                additionalInfo:(nullable NSDictionary *)additionalInfo
{
    self = [super initWithAction:actionId success:YES additionalInfo:additionalInfo];
    if (self)
    {
        if (!tokens)
        {
            return nil;
        }
        NSMutableArray<NSString *> *tokenDescriptions = [NSMutableArray new];
        for (MSIDBaseToken *token in tokens)
        {
            [tokenDescriptions addObject:token.description];
        }
        _tokenDescriptions = [tokenDescriptions copy];
    }
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];

    NSMutableArray *tokensJson = [NSMutableArray new];

    for (NSString *token in self.tokenDescriptions)
    {
        NSString *tokenDescription = [token description];
        if (tokenDescription)
            [tokensJson addObject:tokenDescription];
    }

    json[@"tokens"] = tokensJson;
    return json;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        NSMutableArray *results = [NSMutableArray new];

        for (NSString *tokenDescription in json[@"tokens"])
        {
            [results addObject:tokenDescription];
        }

        _tokenDescriptions = [results copy];
    }

    return self;
}
@end
