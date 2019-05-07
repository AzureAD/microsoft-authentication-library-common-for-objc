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

@property NSDictionary *json;
@property NSMutableDictionary<NSString *, MSIDSharedAccount *> *cacheObjects;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

@implementation MSIDSharedCredentialCacheItem

- (instancetype)init
{
    if(self = [super init])
    {
        self.credentials = [NSMutableDictionary dictionary];
        _cacheObjects = [NSMutableDictionary dictionary];
        _queue = dispatch_queue_create("com.microsoft.universalstorage",
                                       DISPATCH_QUEUE_CONCURRENT);
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

- (void)setObject:(MSIDCredentialCacheItem *)object forKey:(id)key
{
    MSIDDefaultCredentialCacheKey *cacheKey = (MSIDDefaultCredentialCacheKey *)key;
    NSString *accountKey = cacheKey.account;
    MSIDSharedAccount *sharedAccount = [self.credentials objectForKey:accountKey];
    if (!sharedAccount)
    {
        sharedAccount = [MSIDSharedAccount new];
        sharedAccount.accountIdentifier = accountKey;
    }
    
    [sharedAccount.refreshTokens setObject:object forKey:[self getCredentialId:cacheKey]];
    self.credentials[accountKey] = sharedAccount;
    
}

-(MSIDSharedAccount *)objectForKey:(id)key {
    __block id rv = nil;
    
    dispatch_sync(self.queue, ^{ 
        rv = [self.cacheObjects objectForKey:key];
    });
    
    return rv;
}

- (NSString *)getCredentialId: (MSIDDefaultCredentialCacheKey *)key
{
    NSString *clientId = key.familyId ? key.familyId : key.clientId;
    return [key credentialIdWithType:key.credentialType clientId:clientId realm:key.realm enrollmentId:key.enrollmentId];
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    MSID_TRACE;
    if (!(self = [self init]))
    {
        return nil;
    }
    
    if (!json)
    {
        MSID_LOG_WARN(nil, @"Tried to decode a credential cache item from nil json");
        return nil;
    }
    
    _json = json;

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
        
        [self.credentials setObject:sharedAccount forKey:accountKey];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for(NSString *accountKey in self.credentials)
    {
        MSIDSharedAccount *account = [self.credentials objectForKey:accountKey];
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

@end
