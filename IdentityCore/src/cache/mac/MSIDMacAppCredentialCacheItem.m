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

#import "MSIDMacAppCredentialCacheItem.h"

static NSString *keyDelimiter = @"-";

@interface MSIDMacAppCredentialCacheItem ()

@property (nonatomic) NSMutableDictionary *cacheObjects;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation MSIDMacAppCredentialCacheItem

- (instancetype)initPrivate
{
    if(self = [super init])
    {
        self.cacheObjects = [NSMutableDictionary dictionary];
        self.queue = dispatch_queue_create("com.microsoft.universalStorage", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

+ (MSIDMacAppCredentialCacheItem *)sharedInstance
{
    static MSIDMacAppCredentialCacheItem *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initPrivate];
    });
    
    return instance;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [self initPrivate]))
    {
        return nil;
    }
    
    for (NSString *tokenKey in json)
    {
        NSDictionary *rtDict = [json objectForKey:tokenKey];
        
        if (rtDict)
        {
            MSIDCredentialCacheItem *appToken = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:rtDict error:error];
            
            if (appToken)
            {
                MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:appToken.homeAccountId                      environment:appToken.environment clientId:appToken.clientId credentialType:appToken.credentialType];
                
                key.familyId = appToken.familyId;
                key.realm = appToken.realm;
                key.target = appToken.target;
                key.enrollmentId = appToken.enrollmentId;
                
                [self setAppToken:appToken forKey:key];
            }
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSDictionary *cacheObjects = [self getCopy];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (MSIDDefaultCredentialCacheKey *appTokenKey in cacheObjects)
    {
        NSLog(@"%@",appTokenKey.service);
        NSString *key = [NSString stringWithFormat:@"%@%@%@", appTokenKey.account, keyDelimiter, appTokenKey.service];
        MSIDCredentialCacheItem *appToken = [cacheObjects objectForKey:appTokenKey];
        NSDictionary *atDict = [appToken jsonDictionary];
        
        if (atDict)
        {
            [dictionary setObject:atDict forKey:key];
        }
    }
    
    return dictionary;
}

- (void)setAppToken:(MSIDCredentialCacheItem *)token forKey:(MSIDDefaultCredentialCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects setObject:token forKey:key];
    });
}

- (void)removeAppTokenForKey:(MSIDDefaultCredentialCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects removeObjectForKey:key];
    });
}

- (void)mergeCredential:(MSIDMacAppCredentialCacheItem *)credential
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects addEntriesFromDictionary:credential.cacheObjects];
    });
}

- (NSArray<MSIDCredentialCacheItem *> *)credentialsWithKey:(MSIDDefaultCredentialCacheKey *)key
{
    NSMutableArray *subPredicates = [[NSMutableArray alloc] init];
    
    if (key.clientId)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.clientId == %@", key.clientId]];
    if (key.environment)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.environment == %@", key.environment]];
    if (key.homeAccountId)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.homeAccountId == %@", key.homeAccountId]];
    if (key.credentialType)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.credentialType == %d", key.credentialType]];
    if (key.target)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.target == %@", key.target]];
    if (key.realm)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.realm == %@", key.realm]];
    
    // Combine all sub-predicates with AND:
    NSPredicate *matchAttributes = [NSCompoundPredicate andPredicateWithSubpredicates:subPredicates];
    
    NSDictionary *cacheObjects = [self getCopy];
    NSArray<MSIDCredentialCacheItem *> *credentials = [[cacheObjects allValues] filteredArrayUsingPredicate:matchAttributes];
    return credentials;
}

- (NSDictionary *)getCopy
{
    __block NSDictionary *copy;
    
    dispatch_sync(self.queue, ^{
        copy = [self.cacheObjects copy];
    });
    
    return copy;
}

@end
