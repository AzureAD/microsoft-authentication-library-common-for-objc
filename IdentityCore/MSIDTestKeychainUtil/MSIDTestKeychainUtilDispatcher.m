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

#import "MSIDBasicContext.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDClientInfo.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestKeychainUtilDispatcher.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "NSString+MSIDExtensions.h"
#import <Foundation/Foundation.h>

@implementation MSIDTestKeychainUtilDispatcher

NSDictionary* _inputParameters;
MSIDMacKeychainTokenCache *_dataSource;
MSIDAccountCredentialCache *_cache;
MSIDCacheItemJsonSerializer *_serializer;

- (id)init
{
    self = [super init];
    if (self) {
        _serializer = [MSIDCacheItemJsonSerializer new];
    }
    return [super init];
}

- (NSString*) execute:(NSString*)params
{
    NSError *error;
    _inputParameters = [NSJSONSerialization JSONObjectWithData:[params dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:0
                                                         error:&error];
    
    if (error != nil)
    {
        return [self setResponse:@{@"getError": [NSString stringWithFormat:@"Couldn't parse input: '%@'", error], @"text":params}];
    }
    
    NSDictionary *result = [self executeInternal];
    return [self setResponse:result];
}

- (NSString *)setResponse:(NSDictionary *)response
{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

- (NSDictionary *) executeInternal
{
    if ([_inputParameters[@"method"] isEqualToString:@"ReadAccount"]) {
        [self setUp];
        return [self readAccount];
    } else if ([_inputParameters[@"method"] isEqualToString:@"WriteAccount"]) {
        [self setUp];
        return [self writeAccount];
    } else if ([_inputParameters[@"method"] isEqualToString:@"DeleteAccount"]) {
        [self setUp];
        return [self deleteAccount];
    }
    return @{@"status":@-1};
}

- (void) setUp
{
    NSMutableArray<id> *trustedApplications = nil;
    NSArray<NSString*> *trustedApplicationPaths = _inputParameters[@"trustedAppPaths"];
    
    if (trustedApplicationPaths)
    {
        trustedApplications = [[NSMutableArray alloc] initWithCapacity:[trustedApplicationPaths count]];
        for (NSString *appPaths in trustedApplicationPaths)
        {
            SecTrustedApplicationRef trustedApp;
            
            if (SecTrustedApplicationCreateFromPath([appPaths UTF8String], &trustedApp) == errSecSuccess)
            {
                [trustedApplications addObject:(__bridge_transfer id)trustedApp];
            }
        }
    }
    
    _dataSource = [[MSIDMacKeychainTokenCache alloc] initWithGroupAndTrustedApplications:[MSIDMacKeychainTokenCache defaultKeychainGroup]                                                                       trustedApplications:trustedApplications];
    _cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:_dataSource];
}

- (MSIDDefaultAccountCacheKey *) getKeyFromAccount:(MSIDAccountCacheItem*)account
{
    return [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account.homeAccountId
                                                         environment:account.environment
                                                               realm:account.realm
                                                                type:account.accountType];
}

- (NSString *) serializeAccountCacheItem:(MSIDAccountCacheItem *)account
{
    NSData *data = [_serializer serializeCacheItem:account];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (MSIDAccountCacheItem *) deserializeAccountCacheItem:(NSString*)accountString
{
    NSData *accountData = [accountString dataUsingEncoding:NSUTF8StringEncoding];
    MSIDAccountCacheItem *account = (MSIDAccountCacheItem *)[_serializer deserializeCacheItem:accountData ofClass:[MSIDAccountCacheItem class]];
    return account;
}

- (NSDictionary *) readAccount
{
    MSIDAccountCacheItem *account = [self deserializeAccountCacheItem:_inputParameters[@"account"]];
    MSIDDefaultAccountCacheKey *key = [self getKeyFromAccount:account];
    
    NSError *error;
    MSIDAccountCacheItem *accountRead = [_dataSource accountWithKey:key serializer:_serializer context:nil error:&error];
    
    if (error != nil)
    {
        return @{@"getError": [NSString stringWithFormat:@"Couldn't read account: '%@'", error],
                 @"status": @-1
                 };
    }
    
    return @{@"status":@0,
             @"result" : [self serializeAccountCacheItem:accountRead]
             };
}

- (NSDictionary *) writeAccount
{
    MSIDAccountCacheItem *account = [self deserializeAccountCacheItem:_inputParameters[@"account"]];
    MSIDDefaultAccountCacheKey *key = [self getKeyFromAccount:account];
    
    NSError* error;
    BOOL result = [_dataSource saveAccount:account key:key serializer:_serializer context:nil error:&error];
    
    if (error != nil)
    {
        return @{@"getError": [NSString stringWithFormat:@"Couldn't save account: '%@'", error],
                 @"status": @-1,
                 @"result" : @(result)};
    }
    
    return @{@"status":@0,
             @"result": @(result)
             };
}

- (NSDictionary *) deleteAccount
{
    MSIDAccountCacheItem *account = [self deserializeAccountCacheItem:_inputParameters[@"account"]];
    MSIDDefaultAccountCacheKey *key = [self getKeyFromAccount:account];
    
    NSError *error;
    BOOL result = [_dataSource removeAccountsWithKey:key context:nil error:&error];
    
    if (error != nil)
    {
        return @{@"getError": [NSString stringWithFormat:@"Couldn't remove account: '%@'", error],
                 @"status": @-1,
                 @"result" : @(result)};
    }
    
    return @{@"status":@0,
             @"result": @(result)
             };
}

@end
