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

#import "MSIDSharedCredentialCacheItem.h"

@interface MSIDSharedCredentialCacheItem ()

@property NSRecursiveLock *lock;
@property NSMutableDictionary *cacheObjects;
@property NSMutableDictionary *json;

@end


@implementation MSIDSharedCredentialCacheItem

- (instancetype)init
{
    if(self = [super init])
    {
        self.lock = [NSRecursiveLock new];
        self.cacheObjects = [NSMutableDictionary dictionary];
    }
    
    return self;
}

+ (MSIDSharedCredentialCacheItem *)sharedInstance
{
    static MSIDSharedCredentialCacheItem *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MSIDSharedCredentialCacheItem alloc] init];
    });
    
    return instance;
}

- (NSString *)getCredentialId: (MSIDDefaultCredentialCacheKey *)key
{
    [self.lock lock];
    NSString *clientId = key.familyId ? key.familyId : key.clientId;
    NSString *refreshTokenKey = [key credentialIdWithType:key.credentialType clientId:clientId realm:key.realm enrollmentId:key.enrollmentId];
    [self.lock unlock];
    return refreshTokenKey;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    [self.lock lock];
    
    if (!(self = [self init]))
    {
        return nil;
    }
    
    for (NSString *accountKey in json)
    {
        MSIDSharedAccount *sharedAccount = [[MSIDSharedAccount alloc] init];
        sharedAccount.accountIdentifier = accountKey;
        NSDictionary *rtDict = [json valueForKey:accountKey];
        
        if (rtDict && [rtDict isKindOfClass:[NSDictionary class]])
        {
            for (NSString *rtKey in rtDict)
            {
                MSIDCredentialCacheItem *item = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:[rtDict objectForKey:rtKey] error:error];
                if (item)
                {
                    [sharedAccount.refreshTokens setObject:item forKey:rtKey];
                }
            }
        }
        
        [self.cacheObjects setObject:sharedAccount forKey:accountKey];
    }
    
    [self.lock unlock];
    return self;
}

- (NSDictionary *)jsonDictionary
{
    [self.lock lock];
    NSEnumerator *keys = [self keyEnumerator];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (id<NSCopying> accountKey in keys)
    {
        MSIDSharedAccount *account = [self.cacheObjects objectForKey:accountKey];
        if (account)
        {
            NSMutableDictionary *accountDict = [NSMutableDictionary dictionary];
            [dictionary setObject:accountDict forKey:account.accountIdentifier];
            for (NSString *refreshTokenKey in account.refreshTokens)
            {
                MSIDCredentialCacheItem *credItem = [account.refreshTokens objectForKey:refreshTokenKey];
                if (credItem)
                {
                    [accountDict setObject:[credItem jsonDictionary] forKey:refreshTokenKey];
                }
            }
        }
    }
    
    [self.lock unlock];
    return dictionary;
}


- (void)setRefreshToken:(MSIDCredentialCacheItem *)token forKey:(MSIDDefaultCredentialCacheKey *)key
{
    [self.lock lock];
    NSString *accountKey = key.account;
    MSIDSharedAccount *account = [self.cacheObjects objectForKey:accountKey];
    
    if (!account)
    {
        account = [MSIDSharedAccount new];
        account.accountIdentifier = accountKey;
    }
    
    [account.refreshTokens setObject:token forKey:[self getCredentialId:key]];
    [self.cacheObjects setObject:account forKey:accountKey];
    [self.lock unlock];
}

- (NSEnumerator *)keyEnumerator;
{
    NSEnumerator    *result;
    [self.lock lock];
    result = [self.cacheObjects keyEnumerator];
    [self.lock unlock];
    return result;
}

- (MSIDSharedCredentialCacheItem *)mergeCredential:(MSIDSharedCredentialCacheItem *)currentItem
{
    [self.lock lock];
    NSEnumerator *keys = [currentItem keyEnumerator];
    
    for (id<NSCopying> key in keys) {
        MSIDSharedAccount *previousAccount = [self.cacheObjects objectForKey:key];
        MSIDSharedAccount *currentAccount = [currentItem.cacheObjects objectForKey:key];
        if (!previousAccount)
        {
            // The new account was not already in self, so simply add it.
            [self.cacheObjects setObject:currentAccount forKey:key];
        } else
        {
            [self.cacheObjects setObject:[previousAccount mergeAccount:currentAccount] forKey:key];
        }
    }
    
    [self.lock unlock];
    return self;
}

- (NSMutableArray<MSIDCredentialCacheItem *> *)allCredentials
{
    [self.lock lock];
    NSEnumerator *keys = [self keyEnumerator];
    NSMutableArray<MSIDCredentialCacheItem *> *tokenList = [NSMutableArray new];
    
    for (id<NSCopying> key in keys)
    {
        MSIDSharedAccount *account = [self.cacheObjects objectForKey:key];
        if (account)
        {
            for (NSString *key in account.refreshTokens)
            {
                MSIDCredentialCacheItem *sharedCredential = [account.refreshTokens objectForKey:key];
                if (sharedCredential)
                {
                    [tokenList addObject:sharedCredential];
                }
            }
        }
    }
    
    [self.lock unlock];
    return tokenList;
}


@end
