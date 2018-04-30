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

@interface MSIDOpenIdConfigurationInfoResponseSerializer : MSIDAADResponseSerializer
@end

@implementation MSIDOpenIdConfigurationInfoResponseSerializer

- (id)responseObjectForResponse:(NSHTTPURLResponse *)httpResponse
                           data:(NSData *)data
                        context:(id <MSIDRequestContext>)context
                          error:(NSError **)error
{
    NSMutableDictionary *jsonObject = [[super responseObjectForResponse:httpResponse data:data context:context error:error] mutableCopy];
    
    if (error) return nil;
    
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    metadata.authorizationEndpoint = [NSURL URLWithString:jsonObject[@"authorization_endpoint"]];
    metadata.tokenEndpoint = [NSURL URLWithString:jsonObject[@"token_endpoint"]];
    metadata.issuer = [NSURL URLWithString:jsonObject[@"issuer"]];
    
    return metadata;
}

@end

@implementation MSIDOpenIdConfigurationInfoRequest

- (instancetype)initWithEndpoint:(NSURL *)endpoint
{
    self = [super init];
    if (self)
    {
        NSParameterAssert(endpoint);
        
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest new];
        urlRequest.URL = endpoint;
        urlRequest.HTTPMethod = @"GET";
        _urlRequest = urlRequest;
    }
    
    return self;
}

@end
