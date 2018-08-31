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

#import "MSIDOpenIdConfigurationInfoRequest.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAADResponseSerializer.h"
#import "MSIDAuthority.h"

static NSString *s_tenantIdPlaceholder = @"{tenantid}";

@interface MSIDOpenIdConfigurationInfoResponseSerializer : MSIDAADResponseSerializer

@property (nonatomic) NSURL *endpoint;

@end

@implementation MSIDOpenIdConfigurationInfoResponseSerializer

- (id)responseObjectForResponse:(NSHTTPURLResponse *)httpResponse
                           data:(NSData *)data
                        context:(id <MSIDRequestContext>)context
                          error:(NSError **)error
{
    NSError *jsonError;
    NSMutableDictionary *jsonObject = [[super responseObjectForResponse:httpResponse data:data context:context error:&jsonError] mutableCopy];
    
    if (jsonError)
    {
        if (error) *error = jsonError;
        return nil;
    }
    
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    metadata.authorizationEndpoint = [NSURL URLWithString:jsonObject[@"authorization_endpoint"]];
    metadata.tokenEndpoint = [NSURL URLWithString:jsonObject[@"token_endpoint"]];
    
    NSString *issuerString = jsonObject[@"issuer"];
    
    // If `issuer` contains {tenantid}, it is AAD authority.
    // Lets exctract tenant from `endpoint` and put it instead of {tenantid}.
    if ([issuerString containsString:s_tenantIdPlaceholder] && [self.endpoint msidTenant])
    {
        issuerString = [issuerString stringByReplacingOccurrencesOfString:s_tenantIdPlaceholder withString:[self.endpoint msidTenant]];
    }
    
    metadata.issuer = [NSURL URLWithString:issuerString];
    
    return metadata;
}

@end

@implementation MSIDOpenIdConfigurationInfoRequest

- (instancetype)initWithEndpoint:(NSURL *)endpoint
                         context:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        NSParameterAssert(endpoint);
        
        _context = context;
        
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest new];
        urlRequest.URL = endpoint;
        urlRequest.HTTPMethod = @"GET";
        _urlRequest = urlRequest;
        
        __auto_type responseSerializer = [MSIDOpenIdConfigurationInfoResponseSerializer new];
        responseSerializer.endpoint = endpoint;
        _responseSerializer = responseSerializer;
    }
    
    return self;
}

@end
