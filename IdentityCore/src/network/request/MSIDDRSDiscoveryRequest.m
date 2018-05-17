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

#import "MSIDDRSDiscoveryRequest.h"
#import "MSIDAADResponseSerializer.h"
#import "MSIDAADRequestConfigurator.h"
#import "MSIDAADNetworkConfiguration.h"

@interface MSIDDRSDiscoveryResponseSerializer : MSIDAADResponseSerializer
@end

@implementation MSIDDRSDiscoveryResponseSerializer

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
    
    __auto_type endpoint = (NSString *)jsonObject[@"IdentityProviderService"][@"PassiveAuthEndpoint"];
    if (![endpoint isKindOfClass:NSString.class])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     @"PassiveAuthEndpoint is not a string.",
                                     nil,
                                     nil, nil, context.correlationId, nil);
        }
        
        MSID_LOG_ERROR(nil, @"PassiveAuthEndpoint is not a string.");
        return nil;
    }
    
    return [NSURL URLWithString:endpoint];
}

@end

@interface MSIDDRSDiscoveryRequest()

@property (nonatomic) NSString *domain;
@property (nonatomic) MSIDADFSType adfsType;

@end

@implementation MSIDDRSDiscoveryRequest

- (instancetype)initWithDomain:(NSString *)domain
                      adfsType:(MSIDADFSType)adfsType
{
    self = [super init];
    if (self)
    {
        NSParameterAssert(domain);
        
        _domain = domain;
        _adfsType = adfsType;
        
        NSMutableDictionary *parameters = [NSMutableDictionary new];
        parameters[@"api-version"] = MSIDAADNetworkConfiguration.defaultConfiguration.drsDiscoveryApiVersion;
        _parameters = parameters;

        NSMutableURLRequest *urlRequest = [NSMutableURLRequest new];
        urlRequest.URL = [self endpointWithDomain:domain adfsType:adfsType];
        urlRequest.HTTPMethod = @"GET";
        _urlRequest = urlRequest;
        
        __auto_type requestConfigurator = [MSIDAADRequestConfigurator new];
        [requestConfigurator configure:self];
        
        _responseSerializer = [MSIDDRSDiscoveryResponseSerializer new];
    }
    
    return self;
}

- (NSURL *)endpointWithDomain:(NSString *)domain adfsType:(MSIDADFSType)type
{
    if (type == MSIDADFSTypeOnPrems)
    {
        return [NSURL URLWithString:
                [NSString stringWithFormat:@"https://enterpriseregistration.%@/enrollmentserver/contract", domain.lowercaseString]];
    }
    else if (type == MSIDADFSTypeCloud)
    {
        return [NSURL URLWithString:
                [NSString stringWithFormat:@"https://enterpriseregistration.windows.net/%@/enrollmentserver/contract", domain.lowercaseString]];
    }
    
    return nil;
}

@end
