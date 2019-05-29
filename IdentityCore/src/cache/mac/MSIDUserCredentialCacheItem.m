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

#import "MSIDUserCredentialCacheItem.h"
#import "MSIDUserAccount.h"

@interface MSIDUserCredentialCacheItem ()

@property (nonatomic) NSMutableArray *cacheObjects;
@property (nonatomic) dispatch_queue_t queue;

@end


@implementation MSIDUserCredentialCacheItem

- (instancetype)initPrivate
{
    if(self = [super init])
    {
        self.cacheObjects = [NSMutableArray array];
        self.queue = dispatch_queue_create("com.microsoft.universalStorage",DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

+ (MSIDUserCredentialCacheItem *)sharedInstance
{
    static MSIDUserCredentialCacheItem *instance = nil;
    
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
    
    for (NSDictionary *userDict in json)
    {
        NSString *account = [userDict objectForKey:(__bridge id)kSecAttrAccount];
        NSString *service = [userDict objectForKey:(__bridge id)kSecAttrService];
        NSNumber *type = [userDict objectForKey:(__bridge id)kSecAttrType];
        NSData *generic = [[userDict objectForKey:(__bridge id)kSecAttrGeneric] dataUsingEncoding:NSUTF8StringEncoding];
        MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:[userDict objectForKey:(__bridge id)kSecValueData] error:error];
        MSIDUserAccount *userAccount = [[MSIDUserAccount alloc] initWithAccount:account service:service generic:generic type:type credentialCacheItem:cacheItem];
        [self addObject:userAccount];
    }
    
    return self;
}

- (id)jsonDictionary
{
    NSMutableArray *userTokens = [NSMutableArray array];
    NSArray *allTokens = [self allObjects];
    for (MSIDUserAccount *token in allTokens)
    {
        NSMutableDictionary *userToken = [NSMutableDictionary dictionary];
        userToken[(__bridge id)kSecAttrAccount] = token.acct;
        userToken[(__bridge id)kSecAttrService] = token.svce;
        userToken[(__bridge id)kSecAttrGeneric] = [[NSString alloc] initWithData:token.gena encoding:NSUTF8StringEncoding];
        userToken[(__bridge id)kSecAttrType] = token.type;
        userToken[(__bridge id)kSecValueData] = [token.cacheItem jsonDictionary];
        [userTokens addObject:userToken];
    }
    
    return userTokens;
}


- (void)setUserToken:(MSIDCredentialCacheItem *)token forKey:(MSIDDefaultCredentialCacheKey *)key;
{
    MSIDUserAccount *account = [[MSIDUserAccount alloc] initWithAccount:key.account service:key.service generic:key.generic type:key.type credentialCacheItem:token];
    [self addObject:account];
}

- (NSArray<MSIDCredentialCacheItem *> *)credentialsWithKey:(MSIDDefaultCredentialCacheKey *)key;
{
    // Build array of sub-predicates:
    NSMutableArray *subPredicates = [[NSMutableArray alloc] init];
    
    if (key.account)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.acct == %@", key.account]];
    if (key.service)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.svce == %@", key.service]];
    if (key.generic)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.gena == %@", key.generic]];
    if (key.type)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.type == %@", key.type]];
    // Combine all sub-predicates with AND:
    NSPredicate *matchAttributes = [NSCompoundPredicate andPredicateWithSubpredicates:subPredicates];
    NSArray *filteredArray = [[self allObjects] filteredArrayUsingPredicate:matchAttributes];
    NSLog(@"%@",filteredArray);
    
    NSMutableArray<MSIDCredentialCacheItem*> *userCredentials = [NSMutableArray array];
    
    for (MSIDUserAccount *userAccount in filteredArray)
    {
        [userCredentials addObject:userAccount.cacheItem];
    }
    
    return userCredentials;
}

- (void)addObject:(MSIDUserAccount *)obj
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects addObject:obj];
    });
}

- (NSArray*)allObjects {
    __block NSArray *array;
    dispatch_sync(self.queue, ^{
        array = [NSArray arrayWithArray:self.cacheObjects];
    });
    return array;
}


@end
