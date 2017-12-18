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

#import "MSIDTokenCache.h"
#import "MSIDToken.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDTokenCacheDataSource.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDJsonSerializer.h"
#import "MSIDUser.h"

@implementation MSIDTokenCache
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDJsonSerializer *_jsonSerializer;
    MSIDKeyedArchiverSerializer *_keyedArchiverSerialize;
}

- (id)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _dataSource = dataSource;
    return self;
}

- (id<MSIDTokenCacheDataSource>)dataSource
{
    return _dataSource;
}

- (MSIDToken *)getAdalATRTforUser:(MSIDUser *)user
                        authority:(NSURL *)authority
                         resource:(NSString *)resource
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:authority.absoluteString
                                                        clientId:clientId
                                                        resource:resource
                                                             upn:user.upn];
    
    return [_dataSource itemWithKey:key
                         serializer:_keyedArchiverSerialize
                            context:context error:error];
}


- (MSIDAdfsToken *)getAdfsUserTokenForAuthority:(NSURL *)authority
                                       resource:(NSString *)resource
                                       clientId:(NSString *)clientId
                                        context:(id<MSIDRequestContext>)context
                                          error:(NSError **)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAdfsUserTokenWithAuthority:authority.absoluteString
                                                                        clientId:clientId
                                                                        resource:resource];
    
    return (MSIDAdfsToken *)[_dataSource itemWithKey:key
                                          serializer:_keyedArchiverSerialize
                                             context:context
                                               error:error];
}



- (MSIDToken *)getFRTforUser:(MSIDUser *)user
                   authority:(NSURL *)authority
                    familyId:(NSString *)familyId
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    
    if (!familyId)
    {
        familyId = @"1";
    }
    NSString *fociClientId = [NSString stringWithFormat:@"foci-%@", familyId];
    
    return [self getRTforUser:user
                    authority:authority
                     clientId:fociClientId
                      context:context
                        error:error];
}

- (MSIDToken *)getMsalATwithAuthority:(NSURL *)authority
                             clientId:(NSString *)clientId
                               scopes:(NSOrderedSet<NSString *> *)scopes
                                 user:(MSIDUser *)user
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error
{
    // Error check
    if (!user)
    {
        return nil;
    }
    
    // get all access token
    // Get all AT
    //  since clientId is a part of service key, not the whole service key
    //  like RT, we have to do client matching afterwards

    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAllAccessTokensWithUserId:[user userIdentifier]
                                                                    environment:authority.msidHostWithPortIfNecessary];
    
    NSArray<MSIDToken *> *allTokens = [_dataSource itemsWithKey:key serializer:_jsonSerializer context:context error:error];
    
    BOOL anyAccessToken = NO;
    for (MSIDToken *token in allTokens)
    {
        if (token.tokenType == MSIDTokenTypeAccessToken)
        {
            anyAccessToken = YES;
        }
    }
    
    if (!anyAccessToken)
    {
        // This should be rare-to-never as having a MSALUser object requires having a RT in cache,
        // which should imply that at some point we got an AT for that user with this client ID
        // as well. Unless users start working cross client id of course.
        MSID_LOG_WARN(context, @"No access token found for user & client id.");
        MSID_LOG_WARN_PII(context, @"No access token found for user & client id.");
        
        return nil;
    }
    
    NSString *foundAuthority = allTokens[0].authority;
    NSString *absoluteAuthority = authority.absoluteString;
    
    NSMutableArray<MSIDToken *> *matchedTokens = [NSMutableArray<MSIDToken *> new];
    
    for (MSIDToken *token in allTokens)
    {
        if (authority && ![absoluteAuthority isEqualToString:token.authority])
        {
            continue;
        }
        if (![foundAuthority isEqualToString:token.authority])
        {
            // Todo: add macro and handle error
            return nil;
        }
        if (![scopes isSubsetOfOrderedSet:token.scopes])
        {
            continue;
        }
        
        [matchedTokens addObject:token];
    }
    
    if (matchedTokens.count == 0)
    {
        MSID_LOG_INFO(context, @"No matching access token found.");
        MSID_LOG_INFO_PII(context, @"No matching access token found.");
        return nil;
    }
    
    if ([matchedTokens[0] isExpired])
    {
        MSID_LOG_INFO(context, @"Access token found in cache is already expired.");
        MSID_LOG_INFO_PII(context, @"Access token found in cache is already expired.");
        return nil;
    }
    
    return matchedTokens[0];
}


- (MSIDToken *)getRTforUser:(MSIDUser *)user
                             authority:(NSURL *)authority
                              clientId:(NSString *)clientId
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    // Look for new cache, with utid and uid
    if (user.userIdentifier)
    {
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:user.userIdentifier
                                                                        clientId:clientId
                                                                     environment:authority.msidHostWithPortIfNecessary];
        
        MSIDToken *token = [_dataSource itemWithKey:key serializer:_jsonSerializer context:context error:error];
        if (token)
        {
            return token;
        }
    }
    
    // Look for old cache
    // if there is upn
    if (user.upn)
    {
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:authority.absoluteString
                                                            clientId:clientId
                                                            resource:nil
                                                                 upn:user.upn];
        
        MSIDToken *token = [_dataSource itemWithKey:key serializer:_keyedArchiverSerialize context:context error:error];
        
        if (token)
        {
            return token;
        }
    }
    
    return nil;
}

- (NSArray<MSIDToken *> *)getAllRTsForClientId:(NSString *)clientId
                                       context:(id<MSIDRequestContext>)context
                                         error:(NSError **)error
{
    if (!clientId)
    {
        return nil;
    }
    
    NSMutableArray<MSIDToken *> *allRTs = [NSMutableArray<MSIDToken *> new];
    
    // Look at new cache
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForRefreshTokenWithClientId:clientId];
    
    NSArray *newTokens = [_dataSource itemsWithKey:key serializer:_jsonSerializer context:context error:error];
    if (!newTokens)
    {
        return nil;
    }
    
    for (MSIDToken *token in newTokens)
    {
        if (token.tokenType == MSIDTokenTypeRefreshToken)
        {
            [allRTs addObject:token];
        }
    }
    
    // Look at old cache
    NSArray *legacyTokens = [_dataSource itemsWithKey:[MSIDTokenCacheKey keyForAllItems]
                                           serializer:_keyedArchiverSerialize
                                              context:context
                                                error:error];
    
    if (!legacyTokens)
    {
        return nil;
    }
    
    for (MSIDToken *token in legacyTokens)
    {
        if (token.tokenType == MSIDTokenTypeRefreshToken
            && token.clientId == clientId)
        {
            [allRTs addObject:token];
        }
    }
    
    return allRTs;
}

- (BOOL)saveAdalAT:(MSIDToken *)adalAT
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
          resource:(NSString *)resource
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:adalAT.authority
                                                        clientId:clientId
                                                        resource:resource
                                                             upn:user.upn];
    
    return [_dataSource setItem:adalAT
                            key:key
                     serializer:_keyedArchiverSerialize
                        context:context
                          error:error];
}

- (BOOL)saveMsalAT:(MSIDToken *)msalAT
         authority:(NSURL *)authority
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
            scopes:(NSOrderedSet<NSString *> *)scopes
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error
{
    //delete all cache entries with intersecting scopes
    //this should not happen but we have this as a safe guard against multiple matches
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:authority.absoluteString
                                                                      clientId:clientId
                                                                        scopes:scopes
                                                                        userId:user.userIdentifier];
    
    NSArray<MSIDToken *> *allTokens = [_dataSource itemsWithKey:key serializer:_jsonSerializer context:context error:error];
    
    if (!allTokens)
    {
        return NO;
    }

    for (MSIDToken *token in allTokens)
    {
        if (token.tokenType == MSIDTokenTypeAccessToken
            && [token.authority isEqualToString:msalAT.authority]
            && [token.scopes intersectsOrderedSet:msalAT.scopes])
        {
            MSIDTokenCacheKey *keyToDelete = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:token.authority
                                                                                      clientId:token.clientId
                                                                                        scopes:token.scopes
                                                                                        userId:user.userIdentifier];
            
            if(![_dataSource removeItemsWithKey:keyToDelete context:context error:nil])
            {
                return NO;
            }
        }
    }
    
    MSIDTokenCacheKey *atKey = [MSIDTokenCacheKey keyForAccessTokenWithAuthority:msalAT.authority
                                                                        clientId:clientId
                                                                          scopes:msalAT.scopes
                                                                          userId:user.userIdentifier];
                                
    return [_dataSource setItem:msalAT key:atKey serializer:_jsonSerializer context:context error:error];
}

- (BOOL)saveRT:(MSIDToken *)rt
          user:(MSIDUser *)user
     authority:(NSURL *)authority
      clientId:(NSString *)clientId
       context:(id<MSIDRequestContext>)context
         error:(NSError **)error
{
    // save in new form
    if (user.userIdentifier)
    {
        MSIDTokenCacheKey *newKey = [MSIDTokenCacheKey keyForRefreshTokenWithUserId:user.userIdentifier
                                                                           clientId:clientId
                                                                        environment:authority.msidHostWithPortIfNecessary];
        
        if(![_dataSource setItem:rt key:newKey serializer:_jsonSerializer context:context error:error])
        {
            return NO;
        }
    }
    
    // save in old form
    if (user.upn)
    {
        MSIDTokenCacheKey *oldKey = [MSIDTokenCacheKey keyWithAuthority:authority.absoluteString
                                                               clientId:clientId
                                                               resource:nil
                                                                    upn:user.upn];
        if(![_dataSource setItem:rt key:oldKey serializer:_keyedArchiverSerialize context:context error:error])
        {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)saveAdfsToken:(MSIDAdfsToken *)adfsToken
            authority:(NSURL *)authority
             resource:(NSString *)resource
             clientId:(NSString *)clientId
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyForAdfsUserTokenWithAuthority:authority.absoluteString
                                                                        clientId:clientId
                                                                        resource:resource];
    
    return [_dataSource setItem:(MSIDToken *)adfsToken
                            key:key
                     serializer:_keyedArchiverSerialize
                        context:context
                          error:error];
}


@end
