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

#import "MSIDAadAuthorityResolver.h"
#import "MSIDAADAuthorityMetadataRequest.h"
#import "MSIDAuthority.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDNetworkConfiguration.h"

static dispatch_queue_t s_aadValidationQueue;

@implementation MSIDAadAuthorityResolver

+ (void)initialize
{
    if (self == [MSIDAadAuthorityResolver self])
    {
        // A serial dispatch queue for all authority validation operations. A very common pattern is for
        // applications to spawn a bunch of threads and call acquireToken on them right at the start. Many
        // of those acquireToken calls will be to the same authority. To avoid making the exact same
        // authority validation network call multiple times we throw the requests in this validation
        // queue.
        s_aadValidationQueue = dispatch_queue_create("msid.aadvalidation.queue", DISPATCH_QUEUE_SERIAL);
    }
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _aadCache = [MSIDAadAuthorityCache sharedInstance];
    }
    
    return self;
}

- (void)resolveAuthority:(NSURL *)authority
       userPrincipalName:(__unused NSString *)upn
                validate:(BOOL)validate
                 context:(id<MSIDRequestContext>)context
         completionBlock:(MSIDAuthorityInfoBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    
    // We first try to get a record from the cache, this will return immediately if it couldn't
    // obtain a read lock
    MSIDAadAuthorityCacheRecord *record = [self.aadCache tryCheckCache:authority];
    if (record)
    {
        [self handleRecord:record authority:authority completionBlock:completionBlock];
        return;
    }
    
    // If we wither didn't have a cache, or couldn't get the read lock (which only happens if someone
    // has or is trying to get the write lock) then dispatch onto the AAD validation queue.
    dispatch_async(s_aadValidationQueue, ^{
        
        // If we didn't have anything in the cache then we need to hold onto the queue until we
        // get a response back from the server, or timeout, or fail for any other reason
        __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
        
        [self sendDiscoverRequestWithAuthority:authority validate:validate context:context completionBlock:^(NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
         {
             // Because we're on a serialized queue here to ensure that we don't have more then one
             // validation network request at a time, we want to jump off this queue as quick as
             // possible whenever we hit an error to unblock the queue
             dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                 completionBlock(openIdConfigurationEndpoint, validated, error);
             });
             
             dispatch_semaphore_signal(dsem);
         }];
        
        // We're blocking the AAD Validation queue here so that we only process one authority validation
        // request at a time. As an application typically only uses a single AAD authority, this cuts
        // down on the amount of simultaneous requests that go out on multi threaded app launch
        // scenarios.
        if (dispatch_semaphore_wait(dsem, DISPATCH_TIME_NOW) != 0)
        {
            // Only bother logging if we have to wait on the queue.
            MSID_LOG_INFO(context, @"Waiting on Authority Validation Queue");
            dispatch_semaphore_wait(dsem, DISPATCH_TIME_FOREVER);
            MSID_LOG_INFO(context, @"Returned from Authority Validation Queue");
        }
    });
}

#pragma mark - Private

- (void)sendDiscoverRequestWithAuthority:(NSURL *)authority
                                validate:(BOOL)validate
                                 context:(id<MSIDRequestContext>)context
                         completionBlock:(MSIDAuthorityInfoBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    
    // Before we make the request, check the cache again, as these requests happen on a serial queue
    // and it's possible we were waiting on a request that got the information we're looking for.
    MSIDAadAuthorityCacheRecord *record = [self.aadCache checkCache:authority];
    if (record)
    {
        [self handleRecord:record authority:authority completionBlock:completionBlock];
        return;
    }
    
    __auto_type trustedHost = MSIDTrustedAuthorityWorldWide;
    if ([MSIDAuthority isKnownHost:authority])
    {
        trustedHost = authority.msidHostWithPortIfNecessary;
    }
    
    __auto_type endpoint = [MSIDNetworkConfiguration.defaultConfiguration.endpointProvider aadAuthorityDiscoveryEndpointWithHost:trustedHost];
    
    __auto_type *request = [[MSIDAADAuthorityMetadataRequest alloc] initWithEndpoint:endpoint authority:authority];
    request.context = context;
    [request sendWithBlock:^(MSIDAADAuthorityMetadataResponse *response, NSError *error)
     {
         if (error)
         {
             if ([error.userInfo[MSIDOAuthErrorKey] isEqualToString:@"invalid_instance"])
             {
                 [self.aadCache addInvalidRecord:authority oauthError:error context:context];
             }
             
             __auto_type endpoint = validate ? nil : [MSIDNetworkConfiguration.defaultConfiguration.endpointProvider openIdConfigurationEndpointWithUrl:authority];
             error = validate ? error : nil;
             
             completionBlock(endpoint, NO, error);
             return;
         }
         
         if (![self.aadCache processMetadata:response.metadata
                        openIdConfigEndpoint:response.openIdConfigurationEndpoint
                                   authority:authority
                                     context:context
                                       error:&error])
         {
             completionBlock(nil, NO, error);
             return;
         }
         
         completionBlock(response.openIdConfigurationEndpoint, YES, nil);
     }];
}

- (void)handleRecord:(MSIDAadAuthorityCacheRecord *)record
           authority:(NSURL *)authority
     completionBlock:(MSIDAuthorityInfoBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    
    completionBlock(record.openIdConfigurationEndpoint, record.validated, record.error);
}

@end
