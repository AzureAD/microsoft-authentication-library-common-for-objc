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

#import "MSIDBrokerOperationTokenRequest.h"
#import "MSIDBrokerOperationRequest.h"
#import "MSIDConfiguration.h"
#import "MSIDConstants.h"
#import "MSIDRequestParameters.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDVersion.h"
#import "MSIDProviderType.h"
#import "MSIDJsonSerializer.h"
#import "NSDictionary+MSIDJsonSerializable.h"
#import "MSIDClaimsRequest.h"
#import "NSDate+MSIDExtensions.h"

@implementation MSIDBrokerOperationTokenRequest

+ (BOOL)fillRequest:(MSIDBrokerOperationTokenRequest *)request
     withParameters:(MSIDRequestParameters *)parameters
       providerType:(MSIDProviderType)providerType
      enrollmentIds:(NSDictionary *)enrollmentIds
       mamResources:(NSDictionary *)mamResources
    requestSentDate:(NSDate *)requestSentDate
{
    [self fillRequest:request
  keychainAccessGroup:parameters.keychainAccessGroup
       clientMetadata:parameters.appRequestMetadata
clientBrokerKeyCapabilityNotSupported:parameters.clientBrokerKeyCapabilityNotSupported
              context:parameters];
    
    request.configuration = parameters.msidConfiguration;
    request.providerType = providerType;
    request.oidcScope = parameters.oidcScope;
    request.extraQueryParameters = parameters.extraURLQueryParameters;
    request.instanceAware = parameters.instanceAware;
    request.enrollmentIds = enrollmentIds;
    request.mamResources = mamResources;
    request.clientCapabilities = parameters.clientCapabilities;
    request.claimsRequest = parameters.claimsRequest;
    request.requestSentDate = requestSentDate;
    request.nonce = parameters.nonce;
    request.webPageUri = parameters.webPageUri;
    request.clientSku = parameters.clientSku;
    request.skipValidateResultAccount = parameters.skipValidateResultAccount;
    request.forceRefresh = parameters.forceRefresh;
    request.platformSequence = parameters.platformSequence;
    request.allowAnyExtraURLQueryParameters = parameters.allowAnyExtraURLQueryParameters;
    request.ignoreScopeValidation = parameters.ignoreScopeValidation;
    return YES;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        _configuration = [[MSIDConfiguration alloc] initWithJSONDictionary:json error:error];
        if (!_configuration) return nil;
        
        _webPageUri = [json msidStringObjectForKey:@"web_page_uri"];
        
        _providerType = MSIDProviderTypeFromString([json msidStringObjectForKey:MSID_PROVIDER_TYPE_JSON_KEY]);
        
        _oidcScope = [json msidStringObjectForKey:MSID_BROKER_EXTRA_OIDC_SCOPES_KEY];
        
        NSString *extraQueryParam = [json msidStringObjectForKey:MSID_BROKER_EXTRA_QUERY_PARAM_KEY];
        _extraQueryParameters = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:extraQueryParam];
        
        _instanceAware = [json msidBoolObjectForKey:MSID_BROKER_INSTANCE_AWARE_KEY];
        
        NSString *enrollmentIdsStr = [json msidStringObjectForKey:MSID_BROKER_INTUNE_ENROLLMENT_IDS_KEY];
        if (enrollmentIdsStr)
        {
            _enrollmentIds = (NSDictionary *)[[MSIDJsonSerializer new] fromJsonString:enrollmentIdsStr ofType:NSDictionary.class context:nil error:nil];
        }
        
        NSString *mamResourcesStr = [json msidStringObjectForKey:MSID_BROKER_INTUNE_MAM_RESOURCE_KEY];
        if (mamResourcesStr)
        {
            _mamResources = (NSDictionary *)[[MSIDJsonSerializer new] fromJsonString:mamResourcesStr ofType:NSDictionary.class context:nil error:nil];
        }
        
        NSString *clientCapabilitiesStr = [json msidStringObjectForKey:MSID_BROKER_CLIENT_CAPABILITIES_KEY];
        _clientCapabilities = [clientCapabilitiesStr componentsSeparatedByString:@","];
        
        NSString *claimsStr= [json msidStringObjectForKey:MSID_BROKER_CLAIMS_KEY];
        if (claimsStr)
        {
            _claimsRequest = (MSIDClaimsRequest *)[[MSIDJsonSerializer new] fromJsonString:claimsStr ofType:MSIDClaimsRequest.class context:nil error:nil];
        }
        
        _requestSentDate = [NSDate msidDateFromTimeStamp:json[MSID_BROKER_REQUEST_SENT_TIMESTAMP]];
        
        _nonce = [json msidStringObjectForKey:@"nonce"];
        _accountHomeTenantId = [json msidStringObjectForKey:MSID_BROKER_ACCOUNT_HOME_TENANT_ID];

        _clientSku = [json msidStringObjectForKey:MSID_CLIENT_SKU_KEY];
        _skipValidateResultAccount = [json msidBoolObjectForKey:MSID_SKIP_VALIDATE_RESULT_ACCOUNT_KEY];
        _forceRefresh = [json msidBoolObjectForKey:MSID_FORCE_REFRESH_KEY];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    if (!json) return nil;
    
    NSDictionary *configurationJson = [self.configuration jsonDictionary];
    if (!configurationJson)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, self.correlationId, @"Failed to create json for %@ class, configuration is nil.", self.class);
        return nil;
    }
        
    [json addEntriesFromDictionary:configurationJson];
    json[@"web_page_uri"] = self.webPageUri;
    json[MSID_PROVIDER_TYPE_JSON_KEY] = MSIDProviderTypeToString(self.providerType);
    json[MSID_BROKER_EXTRA_OIDC_SCOPES_KEY] = self.oidcScope;
    json[MSID_BROKER_EXTRA_QUERY_PARAM_KEY] = [self.extraQueryParameters msidWWWFormURLEncode];
    json[MSID_BROKER_INSTANCE_AWARE_KEY] = [@(self.instanceAware) stringValue];
    json[MSID_BROKER_INTUNE_ENROLLMENT_IDS_KEY] = [self.enrollmentIds msidJSONSerializeWithContext:nil];
    json[MSID_BROKER_INTUNE_MAM_RESOURCE_KEY] = [self.mamResources msidJSONSerializeWithContext:nil];
    json[MSID_BROKER_CLIENT_CAPABILITIES_KEY] = [self.clientCapabilities componentsJoinedByString:@","];
    json[MSID_BROKER_CLAIMS_KEY] = [[self.claimsRequest jsonDictionary] msidJSONSerializeWithContext:nil];
    json[MSID_BROKER_REQUEST_SENT_TIMESTAMP] = [self.requestSentDate msidDateToFractionalTimestamp:10];
    json[@"nonce"] = self.nonce;
    json[MSID_BROKER_ACCOUNT_HOME_TENANT_ID] = self.accountHomeTenantId;
    json[MSID_CLIENT_SKU_KEY] = self.clientSku;
    json[MSID_SKIP_VALIDATE_RESULT_ACCOUNT_KEY] = [@(self.skipValidateResultAccount) stringValue];
    json[MSID_FORCE_REFRESH_KEY] = [@(self.forceRefresh) stringValue];
    
    return json;
}

@end
