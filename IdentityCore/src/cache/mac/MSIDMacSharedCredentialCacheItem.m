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

#import "MSIDMacSharedCredentialCacheItem.h"

@interface MSIDMacSharedCredentialCacheItem ()

@property (nonatomic) NSMutableDictionary *cacheObjects;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation MSIDMacSharedCredentialCacheItem

- (instancetype)initPrivate
{
    if(self = [super init])
    {
        self.cacheObjects = [NSMutableDictionary dictionary];
        self.queue = dispatch_queue_create("com.microsoft.universalStorage", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

+ (MSIDMacSharedCredentialCacheItem *)sharedInstance
{
    static MSIDMacSharedCredentialCacheItem *instance = nil;
    
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
    
    for (NSString *credentialKey in json)
    {
        MSIDMacSharedCredential *sharedCredential = [[MSIDMacSharedCredential alloc] initWithCredentialIdentifier:credentialKey];
        NSDictionary *rtDict = [json valueForKey:credentialKey];
        
        if (rtDict && [rtDict isKindOfClass:[NSDictionary class]])
        {
            for (NSString *rtKey in rtDict)
            {
                MSIDCredentialCacheItem *credential = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:[rtDict objectForKey:rtKey] error:error];
                if (credential)
                {
                    [sharedCredential.refreshTokens setObject:credential forKey:rtKey];
                }
            }
        }
        
        [self setCredential:sharedCredential forKey:credentialKey];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSArray *keys = [self allKeys];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (NSString *credentialKey in keys)
    {
        MSIDMacSharedCredential *sharedCredential = [self credentialForKey:credentialKey];
        if (sharedCredential)
        {
            NSMutableDictionary *credentialDict = [NSMutableDictionary dictionary];
            [dictionary setObject:credentialDict forKey:sharedCredential.credentialIdentifier];
            for (NSString *refreshTokenKey in sharedCredential.refreshTokens)
            {
                MSIDCredentialCacheItem *credItem = [sharedCredential.refreshTokens objectForKey:refreshTokenKey];
                if (credItem)
                {
                    [credentialDict setObject:[credItem jsonDictionary] forKey:refreshTokenKey];
                }
            }
        }
    }
    
    return dictionary;
}


- (void)setRefreshToken:(MSIDCredentialCacheItem *)token forKey:(MSIDDefaultCredentialCacheKey *)key
{
    NSString *credentialKey = key.account;
    MSIDMacSharedCredential *sharedCredential = [self credentialForKey:credentialKey];
    
    if (!sharedCredential)
    {
        sharedCredential = [[MSIDMacSharedCredential alloc] initWithCredentialIdentifier:credentialKey];
    }
    
    [sharedCredential.refreshTokens setObject:token forKey:[self getCredentialId:key]];
    [self setCredential:sharedCredential forKey:credentialKey];
}

- (NSArray<MSIDCredentialCacheItem *> *)allCredentials
{
    NSArray *keys = [self allKeys];
    NSMutableArray<MSIDCredentialCacheItem *> *tokenList = [NSMutableArray new];
    
    for (NSString *key in keys)
    {
        MSIDMacSharedCredential *sharedCredential = [self credentialForKey:key];
        
        if (sharedCredential)
        {
            for (NSString *key in sharedCredential.refreshTokens)
            {
                MSIDCredentialCacheItem *credential = [sharedCredential.refreshTokens objectForKey:key];
                
                if (sharedCredential)
                {
                    [tokenList addObject:credential];
                }
            }
        }
    }
    
    return [tokenList copy];
}

- (MSIDMacSharedCredential *)credentialForKey:(NSString *)key
{
    __block id rv = nil;
    
    dispatch_sync(self.queue, ^{
        rv = [self.cacheObjects objectForKey:key];
    });
    
    return rv;
}

- (void)setCredential:(MSIDMacSharedCredential *)credential forKey:(NSString *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects setObject:credential forKey:key];
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

- (MSIDMacSharedCredentialCacheItem *)mergeSharedCredential:(MSIDMacSharedCredentialCacheItem *)credential
{
    NSArray *keys = [credential allKeys];
    
    for (NSString *key in keys) {
        MSIDMacSharedCredential *savedCredential = [self credentialForKey:key];
        MSIDMacSharedCredential *currentCredential = [credential credentialForKey:key];
        if (!savedCredential)
        {
            // The new account was not already in self, so simply add it.
            [self setCredential:currentCredential forKey:key];
        }
        else
        {
            MSIDMacSharedCredential *mergedCredential = [self mergeCredential:savedCredential withCredential:currentCredential];
            [self setCredential:mergedCredential forKey:key];
        }
    }
    
    return self;
}

- (MSIDMacSharedCredential *)mergeCredential:(MSIDMacSharedCredential *)currentCredential withCredential:(MSIDMacSharedCredential *)savedCredential
{
    __block MSIDMacSharedCredential *mergeCredential = nil;
    
    dispatch_sync(self.queue, ^{
        mergeCredential = [currentCredential mergeCredential:savedCredential];
    });
    
    return mergeCredential;
}

- (MSIDMacSharedCredentialCacheItem *)removeCredential:(MSIDCredentialCacheItem *)credential
{
    return nil;
}


@end
