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

#import "MSIDClaimsRequest.h"
#import "MSIDIndividualClaimRequestAdditionalInfo.h"
#import "MSIDIndividualClaimRequest.h"

@interface MSIDClaimsRequest()

@property (nonatomic) NSMutableDictionary<NSNumber *, NSMutableSet *> *claimsRequestsDict;

@end

@implementation MSIDClaimsRequest

- (NSSet<NSString *> *)ageAssuranceTargetIdentifiers
{
    NSMutableSet<NSString *> *targets = [NSMutableSet new];
    for (MSIDIndividualClaimRequest *claim in [self claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken])
    {
        if (![claim.name isEqualToString:@"xms_agvs"])
        {
            continue;
        }

        for (id property in claim.additionalInfo.additionalProperties)
        {
            if ([property isKindOfClass:NSString.class] && [[property lowercaseString] hasPrefix:@"target-"])
            {
                // Preserve malformed explicit targets so they fail closed, rather than disabling validation.
                [targets addObject:[[[property substringFromIndex:7] lowercaseString] copy]];
            }
        }
    }
    return [targets copy];
}

+ (BOOL)isAgeAssuranceTargetIdentifier:(NSString *)identifier
{
    if (![identifier isKindOfClass:NSString.class] || identifier.length == 0)
    {
        return NO;
    }
    return ![identifier hasPrefix:@"+"] && ![identifier hasPrefix:@"-"]
        && [identifier rangeOfString:@","].location == NSNotFound
        && [identifier rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location == NSNotFound;
}

+ (BOOL)validateAgeAssuranceIdToken:(NSString *)idToken
                   expectedTargets:(NSSet<NSString *> *)expectedTargets
                     correlationId:(NSUUID *)correlationId
                             error:(NSError *__autoreleasing *)error
{
    if (expectedTargets.count == 0)
    {
        return YES;
    }

    // Read the JWT payload only. Header parameters are not ID-token claims.
    NSArray<NSString *> *parts = [idToken isKindOfClass:NSString.class] ? [idToken componentsSeparatedByString:@"."] : nil;
    NSDictionary *payload = nil;
    if (parts.count == 3)
    {
        NSData *data = [[parts[1] msidBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([json isKindOfClass:NSDictionary.class])
        {
            payload = json;
        }
    }

    id receipt = payload[@"xms_agvt"];
    BOOL valid = [receipt isKindOfClass:NSString.class] && [receipt length] > 0;
    NSMutableSet<NSString *> *actualTargets = [NSMutableSet new];
    if (valid)
    {
        for (NSString *entry in [receipt componentsSeparatedByString:@","])
        {
            if (entry.length < 2 || (![entry hasPrefix:@"+"] && ![entry hasPrefix:@"-"]))
            {
                valid = NO;
                break;
            }
            NSString *identity = [[entry substringFromIndex:1] lowercaseString];
            if (![self isAgeAssuranceTargetIdentifier:identity] || [actualTargets containsObject:identity])
            {
                valid = NO;
                break;
            }
            [actualTargets addObject:identity];
        }
    }
    for (NSString *identity in expectedTargets)
    {
        valid = valid && [self isAgeAssuranceTargetIdentifier:identity];
    }
    if (valid && [actualTargets isEqualToSet:expectedTargets])
    {
        return YES;
    }
    if (error)
    {
        *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorAgeAssuranceTargetMismatch,
                                 @"The ID-token age-assurance receipt does not match the request.",
                                 @"age_assurance_target_mismatch", nil, nil, correlationId, nil, NO);
    }
    return NO;
}

- (NSString *)description
{
    NSString *baseDescription = [super description];
    return [baseDescription stringByAppendingFormat:@"(%@)", [self.claimsRequestsDict description]];
}

- (NSMutableDictionary *)claimsRequestsDict
{
    if (!_claimsRequestsDict) _claimsRequestsDict = [NSMutableDictionary new];
    
    return _claimsRequestsDict;
}

- (NSUInteger)count
{
    return self.claimsRequestsDict.count;
}

- (BOOL)hasClaims
{
    return self.claimsRequestsDict.count != 0;
}

- (BOOL)requestClaim:(MSIDIndividualClaimRequest *)request
           forTarget:(MSIDClaimsRequestTarget)target
               error:(NSError *__autoreleasing*)error
{
    if (!request)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInvalidDeveloperParameter,
                                     @"Claim request is nil.",
                                     nil, nil, nil, nil, nil, NO);
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to request claim: claim request is nil.");
        return NO;
    }
    
    if (target == MSIDClaimsRequestTargetInvalid)
    {
        NSAssert(NO, @"Target is invalid.");
        return NO;
    }
    
    __auto_type key = [[NSNumber alloc] initWithLong:target];
    
    NSMutableSet *requests = self.claimsRequestsDict[key] ?: [NSMutableSet new];
    
    if ([requests containsObject:request]) [requests removeObject:request];
    
    [requests addObject:request];
    
    self.claimsRequestsDict[key] = requests;
    
    return YES;
}

- (NSArray<MSIDIndividualClaimRequest *> *)claimsRequestsForTarget:(MSIDClaimsRequestTarget)target
{
    if (!self.claimsRequestsDict) return nil;
    
    __auto_type key = [[NSNumber alloc] initWithLong:target];
    NSArray *requests = [self.claimsRequestsDict[key] allObjects] ?: [NSArray new];
    
    return requests;
}

- (BOOL)removeClaimRequestWithName:(NSString *)name
                            target:(MSIDClaimsRequestTarget)target
                             error:(NSError *__autoreleasing*)error
{
    if (!name)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInvalidDeveloperParameter,
                                     @"Name is nil.",
                                     nil, nil, nil, nil, nil, NO);
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to remove claim: name is nil.");
        
        return NO;
    }
    
    __auto_type key = [[NSNumber alloc] initWithLong:target];
    if (!self.claimsRequestsDict[key]) return NO;
    
    NSMutableSet *requests = self.claimsRequestsDict[key];
    
    MSIDIndividualClaimRequest *tmpRequest = [[MSIDIndividualClaimRequest alloc] initWithName:name];
    if (![requests containsObject:tmpRequest]) return NO;
        
    [requests removeObject:tmpRequest];
    
    self.claimsRequestsDict[key] = requests;
    
    return YES;
}

#pragma mark - NSCopying

- (id)copyWithZone:(__unused NSZone *)zone
{
    MSIDClaimsRequest *item = [MSIDClaimsRequest new];
    for (NSNumber *target in self.claimsRequestsDict)
    {
        NSMutableSet *requests = [NSMutableSet new];
        for (MSIDIndividualClaimRequest *request in self.claimsRequestsDict[target])
        {
            MSIDIndividualClaimRequest *requestCopy = [[MSIDIndividualClaimRequest alloc] initWithName:[request.name copy]];
            if (request.additionalInfo)
            {
                MSIDIndividualClaimRequestAdditionalInfo *info = [MSIDIndividualClaimRequestAdditionalInfo new];
                info.essential = request.additionalInfo.essential;
                info.value = request.additionalInfo.value;
                info.values = [request.additionalInfo.values copy];
                if (request.additionalInfo.additionalProperties)
                {
                    // Copy strings as well as the array so mutable target identifiers cannot change in flight.
                    info.additionalProperties = [[NSArray alloc] initWithArray:request.additionalInfo.additionalProperties copyItems:YES];
                }
                requestCopy.additionalInfo = info;
            }
            [requests addObject:requestCopy];
        }
        item.claimsRequestsDict[target] = requests;
    }
    return item;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    self = [super init];
    if (self)
    {
        for (NSString *key in [json allKeys])
        {
            NSError *localError;
            __auto_type target = [self targetFromString:key error:&localError];
            if (localError)
            {
                if (error) *error = localError;
                return nil;
            }
            
            if (![json msidAssertTypeIsOneOf:@[NSDictionary.class] ofKey:key required:YES context:nil errorCode:MSIDErrorInvalidDeveloperParameter error:error]) return nil;
            
            NSDictionary *claimRequestsJson = json[key];
            for (NSString *innerKey in [claimRequestsJson allKeys])
            {
                NSDictionary *claimRequestJson = @{innerKey: claimRequestsJson[innerKey]};
                __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithJSONDictionary:claimRequestJson error:&localError];
                
                if (localError)
                {
                    if (error) *error = localError;
                    return nil;
                }
                
                BOOL result = [self requestClaim:claimRequest forTarget:target error:error];
                if (!result) return nil;
            }
        }
    }
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *claimsRequestJson = [NSMutableDictionary new];
    
    for (NSNumber *target in self.claimsRequestsDict.allKeys)
    {
        NSSet *requests = self.claimsRequestsDict[target];
        if (requests.count == 0) continue;
        
        __auto_type requestsJson = [NSMutableDictionary new];
        
        for (MSIDIndividualClaimRequest *request in requests)
        {
            NSDictionary *requestJson = [request jsonDictionary];
            if (!requestJson) return nil;
            
            [requestsJson addEntriesFromDictionary:requestJson];
        }
        
        NSString *targetString = [self stringFromTarget:[target integerValue]];
        claimsRequestJson[targetString] = requestsJson;
    }
    
    return claimsRequestJson;
}

#pragma mark - Private

- (MSIDClaimsRequestTarget)targetFromString:(NSString *)string error:(NSError *__autoreleasing*)error
{
    if ([string isEqualToString:MSID_OAUTH2_ID_TOKEN]) return MSIDClaimsRequestTargetIdToken;
    if ([string isEqualToString:MSID_OAUTH2_ACCESS_TOKEN]) return MSIDClaimsRequestTargetAccessToken;
    
    if (error)
    {
        __auto_type message = [NSString stringWithFormat:@"Invalid claims target: %@", string];
        *error = MSIDCreateError(MSIDErrorDomain,
                                 MSIDErrorInvalidDeveloperParameter,
                                 message,
                                 nil, nil, nil, nil, nil, NO);
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Invalid claims target: %@", string);
    
    return MSIDClaimsRequestTargetInvalid;
}

- (NSString *)stringFromTarget:(MSIDClaimsRequestTarget)target
{
    if (target == MSIDClaimsRequestTargetIdToken) return MSID_OAUTH2_ID_TOKEN;
    if (target == MSIDClaimsRequestTargetAccessToken) return MSID_OAUTH2_ACCESS_TOKEN;
    
    NSAssert(NO, @"There is no string representation for provided target.");
    return nil;
}

@end
