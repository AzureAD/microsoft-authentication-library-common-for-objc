//
//  MSIDDefaultTokenResponseValidatorTests.m
//  IdentityCoreTests iOS
//
//  Created by Sergey Demchenko on 12/27/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDConfiguration.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponse.h"

@interface MSIDDefaultTokenResponseValidatorTests : XCTestCase

@property (nonatomic) MSIDDefaultTokenResponseValidator *validator;

@end

@implementation MSIDDefaultTokenResponseValidatorTests

- (void)setUp
{
    self.validator = [MSIDDefaultTokenResponseValidator new];
}

- (void)tearDown
{
}

#pragma mark - Tests

- (void)testValidateTokenResult_whenSomeScopesRejectedByServer_shouldReturnErrorWithGrantedScopesButWithoutDefaultOidcScopes
{
    __auto_type defaultOidcScope = @"openid profile offline_access";
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" authority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:@"fakescope1 fakescope2"];
    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:nil
                                                               responseRT:nil
                                                               responseID:nil
                                                            responseScope:@"openid profile offline_access user.read user.write"
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    NSError *error;
    
    [self.validator validateTokenResult:result
                          configuration:configuration
                              oidcScope:defaultOidcScope
                         requestAccount:nil
                          correlationID:correlationID
                                  error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerDeclinedScopes);
    NSArray *declinedScopes = @[@"fakescope1", @"fakescope2"];
    XCTAssertEqualObjects(error.userInfo[MSIDDeclinedScopesKey], declinedScopes);
    NSArray *grantedScopes = @[@"user.read", @"user.write"];
    XCTAssertEqualObjects(error.userInfo[MSIDGrantedScopesKey], grantedScopes);
}


@end
