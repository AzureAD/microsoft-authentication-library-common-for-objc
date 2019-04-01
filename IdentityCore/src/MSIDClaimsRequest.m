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
#import "MSIDIndividualClaimRequest.h"
#import "MSIDIndividualClaimRequestAdditionalInfo.h"

@interface MSIDClaimsRequest()

@property (nonatomic) NSMutableDictionary *claimsRequestsDict;

@end

@implementation MSIDClaimsRequest

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

- (void)requestClaim:(MSIDIndividualClaimRequest *)request
                 forTarget:(MSIDClaimsRequestTarget)target;
{
    if (!request) return;
    
    __auto_type key = [[NSNumber alloc] initWithInt:target];
    
    NSMutableSet *requests = self.claimsRequestsDict[key] ?: [NSMutableSet new];
    
    if ([requests containsObject:request]) [requests removeObject:request];
    
    [requests addObject:request];
    
    self.claimsRequestsDict[key] = requests;
}

- (NSArray<MSIDIndividualClaimRequest *> *)claimRequestsForTarget:(MSIDClaimsRequestTarget)target
{
    if (!self.claimsRequestsDict) return nil;
    
    __auto_type key = [[NSNumber alloc] initWithInt:target];
    NSArray *requests = [self.claimsRequestsDict[key] allObjects] ?: [NSArray new];
    
    return requests;
}

- (void)removeClaimRequestWithName:(NSString *)name target:(MSIDClaimsRequestTarget)target
{
    if (!name) return;
    
    __auto_type key = [[NSNumber alloc] initWithInt:target];
    if (!self.claimsRequestsDict[key]) return;
    
    NSMutableSet *requests = self.claimsRequestsDict[key];
    
    MSIDIndividualClaimRequest *tmpRequest = [MSIDIndividualClaimRequest new];
    tmpRequest.name = name;
    if (![requests containsObject:tmpRequest]) return;
        
    [requests removeObject:tmpRequest];
    
    self.claimsRequestsDict[key] = requests;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
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
            
            if (![json msidAssertType:NSDictionary.class
                              ofField:key
                              context:nil
                            errorCode:MSIDErrorInvalidDeveloperParameter
                                error:error])
            {
                return nil;
            }
            
            NSDictionary *claimRequestsJson = json[key];
            for (NSString *key in [claimRequestsJson allKeys])
            {
                NSDictionary *claimRequestJson = @{key: claimRequestsJson[key]};
                __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithJSONDictionary:claimRequestJson error:&localError];
                
                if (localError)
                {
                    if (error) *error = localError;
                    return nil;
                }
                
                [self requestClaim:claimRequest forTarget:target];
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
        NSArray *requests = self.claimsRequestsDict[target];
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

- (MSIDClaimsRequestTarget)targetFromString:(NSString *)string error:(NSError **)error
{
    if ([string isEqualToString:MSID_OAUTH2_ID_TOKEN]) return MSIDClaimsRequestTargetIdToken;
    if ([string isEqualToString:MSID_OAUTH2_ACCESS_TOKEN]) return MSIDClaimsRequestTargetAccessToken;
    
    if (error)
    {
        __auto_type message = [NSString stringWithFormat:@"Invalid claims target: %@", string];
        *error = MSIDCreateError(MSIDErrorDomain,
                                 MSIDErrorInvalidDeveloperParameter,
                                 message,
                                 nil, nil, nil, nil, nil);
    }
    
    return MSIDClaimsRequestTargetInvalid;
}

- (NSString *)stringFromTarget:(MSIDClaimsRequestTarget)target
{
    if (target == MSIDClaimsRequestTargetIdToken) return MSID_OAUTH2_ID_TOKEN;
    if (target == MSIDClaimsRequestTargetAccessToken) return MSID_OAUTH2_ACCESS_TOKEN;
    
    MSID_LOG_ERROR(nil, @"There is no string representation for provided target.");
    return nil;
}

@end
