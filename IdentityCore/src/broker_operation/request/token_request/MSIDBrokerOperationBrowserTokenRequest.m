//
//  MSIDBrokerOperationBrowserTokenRequest.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/2/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationBrowserTokenRequest.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDAADAuthority.h"

static NSArray *_bundleIdentifierWhiteList = nil;

@implementation MSIDBrokerOperationBrowserTokenRequest

- (instancetype)initWithRequest:(NSURL *)requestURL
                        headers:(NSDictionary *)headers
               bundleIdentifier:(NSString *)bundleIdentifier
{
    self = [super init];
    if (self)
    {
        _requestURL = requestURL;
        
        if (![self isAuthorizeRequest:_requestURL])
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelInfo, self.correlationId, @"Failed to create browser operation request for %@ class, request is not authorize request", self.class);
            return nil;
        }
        
        _headers = headers;
        
        if (![_bundleIdentifierWhiteList containsObject:bundleIdentifier])
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelInfo, self.correlationId, @"Failed to create browser operation request for %@ class, bundle identifier %@ is not in the whitelist", self.class, _bundleIdentifier);
            return nil;
        }
        
        _bundleIdentifier = bundleIdentifier;
        
        NSError *error = nil;
        MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:_requestURL rawTenant:nil context:nil error:&error];
        
        if (!authority)
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelError, self.correlationId, @"Failed to create browser operation request for %@ class, authority is not AAD authority", self.class);
            return nil;
        }
        
        _authority = authority;
        
        _correlationId = [NSUUID UUID];
    }
    
    return self;
}

+ (void) initialize
{
  if (self == [MSIDBrokerOperationBrowserTokenRequest class])
  {
      _bundleIdentifierWhiteList = @[@"com.apple.mobilesafari"];
  }
}

- (BOOL)isAuthorizeRequest:(NSURL *)url
{
    NSString *request = [url absoluteString];
    return ([request rangeOfString:@"oauth2" options:NSCaseInsensitiveSearch].location != NSNotFound);
}

#pragma mark - MSIDBaseBrokerOperationRequest

+ (NSString *)operation
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_GET_PRT;
}

- (NSString *)description
{
    NSString *baseDescription = [super description];
    return [baseDescription stringByAppendingFormat:@"(requestUrl=%@, bundle_identifier=%@)", self.requestURL, self.bundleIdentifier];
}

@end
