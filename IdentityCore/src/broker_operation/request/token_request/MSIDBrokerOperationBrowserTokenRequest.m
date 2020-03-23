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
        
        if (![_bundleIdentifierWhiteList containsObject:bundleIdentifier])
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelInfo, self.correlationId, @"Failed to create browser operation request for %@ class, bundle identifier %@ is not in the whitelist", self.class, _bundleIdentifier);
            return nil;
        }
        
        _bundleIdentifier = bundleIdentifier;
        
        if (![self isAuthorizeRequest:_requestURL])
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelInfo, self.correlationId, @"Failed to create browser operation request for %@ class, request is not authorize request", self.class);
            return nil;
        }
        
        _headers = headers;
        
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

- (id)logInfo
{
    return [NSString stringWithFormat:@"(requestUrl=%@, bundle_identifier=%@)", self.requestURL, self.bundleIdentifier];
}
@end
