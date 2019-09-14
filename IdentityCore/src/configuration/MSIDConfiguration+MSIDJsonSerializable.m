//
//  MSIDConfiguration+MSIDJsonSerializable.m
//  IdentityCore iOS
//
//  Created by Serhii Demchenko on 2019-09-14.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDConfiguration+MSIDJsonSerializable.h"
#import "MSIDAADAuthority.h"

@implementation MSIDConfiguration (MSIDJsonSerializable)

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_CLIENT_ID
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *clientId = json[MSID_OAUTH2_CLIENT_ID];
    
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_REDIRECT_URI
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *redirectUri = json[MSID_OAUTH2_REDIRECT_URI];
    
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_SCOPE
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *scopeString = json[MSID_OAUTH2_SCOPE];
    
    if (![json msidAssertType:NSString.class
                      ofField:MSID_OAUTH2_AUTHORITY
                      context:nil
                    errorCode:MSIDErrorInvalidInternalParameter
                        error:error])
    {
        return nil;
    }
    NSString *authorityString = json[MSID_OAUTH2_AUTHORITY];
    
    if ([NSString msidIsStringNilOrBlank:authorityString])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Authority is missing in the json dictionary.");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Authority is missing in the json dictionary.", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    // TODO: should we support other authorities?
    NSError *localError = nil;
    MSIDAADAuthority *aadAuthority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:authorityString]
                                                                 rawTenant:nil
                                                                   context:nil
                                                                     error:&localError];
    
    if (!aadAuthority)
    {
        if (error)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Non AAD authorities are not supported for json serialization/deserialization - %@", MSID_PII_LOG_MASKABLE(localError));
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Non AAD authorities are not supported in broker", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    self = [self initWithAuthority:aadAuthority
                       redirectUri:redirectUri
                          clientId:clientId
                            target:scopeString];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[MSID_OAUTH2_CLIENT_ID] = self.clientId;
    json[MSID_OAUTH2_REDIRECT_URI] = self.redirectUri;
    json[MSID_OAUTH2_SCOPE] = self.target;
    json[MSID_OAUTH2_AUTHORITY] = self.authority.url.absoluteURL;
    
    return json;
}

@end
