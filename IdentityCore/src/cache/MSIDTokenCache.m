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
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:authority
                                                             upn:user.upn
                                                        resource:resource
                                                        clientId:clientId];
    
    return [_dataSource itemWithKey:key
                         serializer:_keyedArchiverSerialize
                            context:context error:error];
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
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:authority
                                                             upn:user.upn
                                                        resource:nil
                                                        clientId:fociClientId];
    
    return [_dataSource itemWithKey:key
                         serializer:_keyedArchiverSerialize
                            context:context error:error];
}

- (MSIDToken *)getAdfsUserTokenForAuthority:(NSURL *)authority
                                   resource:(NSString *)resource
                                   clientId:(NSString *)clientId
                                    context:(id<MSIDRequestContext>)context
                                      error:(NSError **)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:authority
                                                             upn:nil
                                                        resource:resource
                                                        clientId:clientId];
    
    return [_dataSource itemWithKey:key serializer:_keyedArchiverSerialize context:context error:error];
}




- (BOOL)getMsalATwithAuthority:(NSURL *)authority
                      clientId:(NSString *)clientId
                        scopes:(NSOrderedSet<NSString *> *)scopes
                          user:(MSIDUser *)user
                   environment:(NSString *)environment
                   accessToken:(MSIDToken **)outAccessToken
                authorityFound:(NSURL **)outAuthorityFound
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    // get all access token
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithUserId:[user userIdentifier] environment:environment clientId:clientId];
    
    NSArray<MSIDToken *> *allTokens = [_dataSource itemsWithKey:key serializer:_jsonSerializer context:context error:error];
    if (!allTokens)
    {
        // This should be rare-to-never as having a MSALUser object requires having a RT in cache,
        // which should imply that at some point we got an AT for that user with this client ID
        // as well. Unless users start working cross client id of course.
        MSID_LOG_WARN(context, @"No access token found for user & client id.");
        MSID_LOG_WARN_PII(context, @"No access token found for user & client id.");
        
        return NO;
    }
    
    NSURL *foundAuthority = allTokens.count > 0 ? allTokens[0].authority : nil;
    
    NSMutableArray<MSIDToken *> *matchedTokens = [NSMutableArray<MSIDToken *> new];
    
    for (MSIDToken *token in allTokens)
    {
        if (authority)
        {
            if (![authority msidIsEquivalentAuthority:token.authority])
            {
                continue;
            }
        }
        else if (![foundAuthority msidIsEquivalentAuthority:token.authority])
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
    
    *outAuthorityFound = foundAuthority;
    
    if (matchedTokens.count == 0)
    {
        MSID_LOG_INFO(context, @"No matching access token found.");
        MSID_LOG_INFO_PII(context, @"No matching access token found.");
        return YES;
    }
    
    if ([matchedTokens[0] isExpired])
    {
        MSID_LOG_INFO(context, @"Access token found in cache is already expired.");
        MSID_LOG_INFO_PII(context, @"Access token found in cache is already expired.");
        return YES;
    }
    
    *outAccessToken = matchedTokens[0];
    return YES;
}

- (NSArray<MSIDToken *> *)getRTsForUser:(MSIDUser *)user
                              authority:(NSURL *)authority
                               clientId:(NSString *)clientId
                                context:(id<MSIDRequestContext>)context
                                  error:(NSError **)error
{
    // Look for new cache, with utid and uid
    if (user.userIdentifier)
    {
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithUserId:user.userIdentifier
                                                      environment:authority.msidHostWithPortIfNecessary
                                                         clientId:clientId];
        
        NSArray<MSIDToken *> *tokens = [_dataSource itemsWithKey:key
                                                      serializer:_jsonSerializer
                                                         context:context
                                                           error:error];
        if (tokens && tokens.count > 0)
        {
            return tokens;
        }
    }
    
    // Look for old cache
    // if there is upn
    if (user.upn)
    {
        MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:authority upn:user.upn resource:nil clientId:clientId];
        
        NSArray<MSIDToken *> *tokens = [_dataSource itemsWithKey:key serializer:_keyedArchiverSerialize context:context error:error];
        NSMutableArray<MSIDToken *> *tokensToReturn = [NSMutableArray<MSIDToken *> new];
        
        for (MSIDToken *token in tokens)
        {
            if (token.tokenType == REFRESH_TOKEN)
            {
                [tokensToReturn addObject:token];
            }
        }
        return tokensToReturn;
    }
    
    return @[];
    
}

- (BOOL)saveAdalAT:(MSIDToken *)adalAT
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
          resource:(NSString *)resource
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithAuthority:adalAT.authority
                                                             upn:user.upn
                                                        resource:resource
                                                        clientId:clientId];
    return [_dataSource setItem:adalAT
                            key:key
                     serializer:_keyedArchiverSerialize
                        context:context
                          error:error];
}

- (BOOL)saveMsalAT:(MSIDToken *)msalAT
          clientId:(NSString *)clientId
              user:(MSIDUser *)user
       environment:(NSString *)environment
           context:(id<MSIDRequestContext>)context
             error:(NSError **)error
{
    //delete all cache entries with intersecting scopes
    //this should not happen but we have this as a safe guard against multiple matches
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey keyWithUserId:[user userIdentifier] environment:environment clientId:clientId];
    
    NSArray<MSIDToken *> *allTokens = [_dataSource itemsWithKey:key serializer:_jsonSerializer context:context error:nil];

    for (MSIDToken *token in allTokens)
    {
        if (token.tokenType == ACCESS_TOKEN
            && [token.authority msidIsEquivalentAuthority:msalAT.authority]
            && [token.scopes intersectsOrderedSet:msalAT.scopes])
        {
            MSIDTokenCacheKey *keyToDelete = [MSIDTokenCacheKey keyWithAuthority:token.authority
                                                                        clientId:clientId
                                                                          scopes:token.scopes
                                                                          userId:user.userIdentifier
                                                                     environment:environment];
            
            [_dataSource removeItemWithKey:keyToDelete context:context error:nil];
        }
    }
    
    MSIDTokenCacheKey *atKey = [MSIDTokenCacheKey keyWithAuthority:msalAT.authority
                                                          clientId:clientId
                                                            scopes:msalAT.scopes
                                                            userId:user.userIdentifier
                                                       environment:environment];
                                
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
        MSIDTokenCacheKey *newKey = [MSIDTokenCacheKey keyWithUserId:user.userIdentifier
                                                         environment:authority.msidHostWithPortIfNecessary
                                                            clientId:clientId];
        
        if(![_dataSource setItem:rt key:newKey serializer:_jsonSerializer context:context error:error])
        {
            return NO;
        }
    }
    
    // save in old form
    if (user.upn)
    {
        MSIDTokenCacheKey *oldKey = [MSIDTokenCacheKey keyWithAuthority:authority upn:user.upn resource:nil clientId:clientId];
        if(![_dataSource setItem:rt key:oldKey serializer:_keyedArchiverSerialize context:context error:error])
        {
            return NO;
        }
    }
    
    return YES;
}

@end
