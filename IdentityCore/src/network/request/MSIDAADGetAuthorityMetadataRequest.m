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

#import "MSIDAADGetAuthorityMetadataRequest.h"
#import "MSIDAADResponseSerializer.h"
#import "MSIDAADRequestConfigurator.h"

@interface MSIDAADAuthorityMetadataResponseSerializer : MSIDAADResponseSerializer
@end

@implementation MSIDAADAuthorityMetadataResponseSerializer

- (id)responseObjectForResponse:(NSHTTPURLResponse *)httpResponse
                           data:(NSData *)data
                        context:(id <MSIDRequestContext>)context
                          error:(NSError **)error
{
    NSMutableDictionary *jsonObject = [[super responseObjectForResponse:httpResponse data:data context:context error:error] mutableCopy];

    if (error) return nil;

    __auto_type reponse = [MSIDAADAuthorityMetadataResponse new];
    
    NSString *oauthError = jsonObject[@"error"];
    if (![NSString msidIsStringNilOrBlank:oauthError])
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain,
                                            MSIDErrorDeveloperAuthorityValidation,
                                            jsonObject[@"error_description"],
                                            oauthError,
                                            nil, nil, context.correlationId, nil);
        return nil;
    }

    reponse.metadata = jsonObject[@"metadata"];
    reponse.openIdConfigurationEndpoint = [NSURL URLWithString:jsonObject[@"tenant_discovery_endpoint"]];

    return reponse;
}

@end

@implementation MSIDAADAuthorityMetadataResponse
@end

@implementation MSIDAADGetAuthorityMetadataRequest

- (instancetype)initWithEndpoint:(NSURL *)endpoint
                       authority:(NSURL *)authority
{
    self = [super init];
    if (self)
    {
        NSParameterAssert(endpoint);
        NSParameterAssert(authority);
        
        NSMutableDictionary *parameters = [_parameters mutableCopy];
        parameters[@"api-version"] = @"1.1";
        __auto_type authorizationEndpoint = [authority.absoluteString.lowercaseString stringByAppendingString:MSID_OAUTH2_AUTHORIZE_SUFFIX()];
        parameters[@"authorization_endpoint"] = authorizationEndpoint;
        
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest new];
        urlRequest.URL = [endpoint URLByAppendingPathComponent:MSID_OAUTH2_INSTANCE_DISCOVERY_SUFFIX];
        urlRequest.HTTPMethod = @"GET";
        _urlRequest = urlRequest;
        
        _requestConfigurator = [MSIDAADRequestConfigurator new];
        _responseSerializer = [MSIDAADAuthorityMetadataResponseSerializer new];
    }
    
    return self;
}

@end
