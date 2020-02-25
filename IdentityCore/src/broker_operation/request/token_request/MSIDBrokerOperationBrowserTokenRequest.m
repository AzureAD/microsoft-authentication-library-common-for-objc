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
        _headers = headers;
        
        if (![_bundleIdentifierWhiteList containsObject:bundleIdentifier])
        {
            return nil;
        }
        
        _bundleIdentifier = bundleIdentifier;
        
        NSError *error = nil;
        MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:_requestURL rawTenant:nil context:nil error:&error];
        
        if (!authority)
        {
            return nil;
        }
        
        _authority = authority;
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

#pragma mark - MSIDBaseBrokerOperationRequest

+ (NSString *)operation
{
    return MSID_JSON_TYPE_OPERATION_REQUEST_GET_PRT;
}

@end
