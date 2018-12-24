//
//  MSIDTokenResponseSerializer.m
//  IdentityCore
//
//  Created by Sergey Demchenko on 12/22/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDAADTokenResponseSerializer.h"
#import "MSIDOauth2Factory.h"
#import "MSIDAADJsonResponsePreprocessor.h"

@interface MSIDAADTokenResponseSerializer()

@property (nonatomic) MSIDOauth2Factory *oauth2Factory;

@end

@implementation MSIDAADTokenResponseSerializer

- (instancetype)initWithOauth2Factory:(MSIDOauth2Factory *)oauth2Factory
{
    self = [super init];
    if (self)
    {
        _oauth2Factory = oauth2Factory;
        self.preprocessor = [MSIDAADJsonResponsePreprocessor new];
    }
    return self;
}

- (id)responseObjectForResponse:(NSHTTPURLResponse *)httpResponse
                           data:(NSData *)data
                        context:(id <MSIDRequestContext>)context
                          error:(NSError **)error
{
    NSError *localError;
    NSDictionary *jsonObject = [super responseObjectForResponse:httpResponse
                                                           data:data
                                                        context:context
                                                          error:&localError];
    
    if (localError)
    {
        if (error) *error = localError;
        return nil;
    }
    
    MSIDTokenResponse *tokenResponse = [self.oauth2Factory tokenResponseFromJSON:jsonObject
                                                                         context:context
                                                                           error:error];
    if (!tokenResponse)
    {
        MSID_LOG_ERROR(context, @"Failed to parse token response.");
        return nil;
    }
    
    return tokenResponse;
}

@end
