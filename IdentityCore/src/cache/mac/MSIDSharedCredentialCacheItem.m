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

@property (nonatomic) NSMutableDictionary *cacheObjects;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation MSIDSharedCredentialCacheItem

- (instancetype)initPrivate
{
    if(self = [super init])
    {
        self.cacheObjects = [NSMutableDictionary dictionary];
        self.queue = dispatch_queue_create("com.microsoft.universalStorage", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

+ (MSIDSharedCredentialCacheItem *)sharedInstance
{
    static MSIDSharedCredentialCacheItem *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initPrivate];
    });
    
    return instance;
}

- (NSString *)getCredentialId: (MSIDDefaultCredentialCacheKey *)key
{
    NSString *clientId = key.familyId ? key.familyId : key.clientId;
    NSString *refreshTokenKey = [key credentialIdWithType:key.credentialType clientId:clientId realm:key.realm enrollmentId:key.enrollmentId];
    return refreshTokenKey;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [self initPrivate]))
    {
        return nil;
    }
    
    for (NSString *accountKey in json)
    {
        MSIDSharedAccount *sharedAccount = [[MSIDSharedAccount alloc] initWithAccountIdentifier:accountKey];
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
        
        [self setObject:sharedAccount forKey:accountKey];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSArray *keys = [self allKeys];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (NSString *accountKey in keys)
    {
        MSIDSharedAccount *account = [self objectForKey:accountKey];
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
    
    return dictionary;
}


- (void)setRefreshToken:(MSIDCredentialCacheItem *)token forKey:(MSIDDefaultCredentialCacheKey *)key
{
    NSString *accountKey = key.account;
    MSIDSharedAccount *account = [self objectForKey:accountKey];
    
    if (!account)
    {
        account = [[MSIDSharedAccount alloc] initWithAccountIdentifier:accountKey];
    }
    
    [account.refreshTokens setObject:token forKey:[self getCredentialId:key]];
    [self setObject:account forKey:accountKey];
}

- (NSMutableArray<MSIDCredentialCacheItem *> *)allCredentials
{
    NSArray *keys = [self allKeys];
    NSMutableArray<MSIDCredentialCacheItem *> *tokenList = [NSMutableArray new];
    
    for (NSString *key in keys)
    {
        MSIDSharedAccount *account = [self objectForKey:key];
        
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
    
    return tokenList;
}

- (MSIDSharedAccount *)objectForKey:(NSString *)key
{
    __block id rv = nil;
    
    dispatch_sync(self.queue, ^{
        rv = [self.cacheObjects objectForKey:key];
    });
    
    return rv;
}

- (void)setObject:(MSIDSharedAccount *)account forKey:(NSString *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects setObject:account forKey:key];
    });
}

- (NSArray *)allKeys
{
    __block NSArray *keys = nil;
    
    dispatch_sync(self.queue, ^{
        keys = [self.cacheObjects allKeys];
    });
    
    return keys;
}

- (MSIDSharedCredentialCacheItem *)mergeCredential:(MSIDSharedCredentialCacheItem *)savedCredential
{
    NSArray *keys = [savedCredential allKeys];
    
    for (NSString *key in keys) {
        MSIDSharedAccount *previousAccount = [self objectForKey:key];
        MSIDSharedAccount *currentAccount = [savedCredential objectForKey:key];
        if (!previousAccount)
        {
            // The new account was not already in self, so simply add it.
            [self setObject:currentAccount forKey:key];
        }
        else
        {
            MSIDSharedAccount *mergedAccount = [self mergeAccount:previousAccount withAccount:currentAccount];
            [self setObject:mergedAccount forKey:key];
        }
    }
    
    return self;
}

- (MSIDSharedAccount *)mergeAccount:(MSIDSharedAccount *)currentAccount withAccount:(MSIDSharedAccount *)savedAccount
{
    __block MSIDSharedAccount *account = nil;
    
    dispatch_sync(self.queue, ^{
        account = [currentAccount mergeAccount:savedAccount];
    });
    
    return account;
}
@end
