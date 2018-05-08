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

#import "MSIDOAuth2Constants.h"
#import "MSIDConfiguration.h"

NSString *const MSID_OAUTH2_ACCESS_TOKEN       = @"access_token";
NSString *const MSID_OAUTH2_AUTHORIZATION      = @"authorization";
//NSString *const MSID_OAUTH2_AUTHORIZE_SUFFIX   = @"/oauth2/authorize";
NSString *const MSID_OAUTH2_AUTHORITY           = @"authority";
NSString *const MSID_OAUTH2_AUTHORIZATION_CODE = @"authorization_code";
NSString *const MSID_OAUTH2_AUTHORIZATION_URI  = @"authorization_uri";
NSString *const MSID_OAUTH2_BEARER             = @"Bearer";
NSString *const MSID_OAUTH2_CLIENT_ID          = @"client_id";
NSString *const MSID_OAUTH2_CODE               = @"code";
NSString *const MSID_OAUTH2_ERROR              = @"error";
NSString *const MSID_OAUTH2_ERROR_DESCRIPTION  = @"error_description";
NSString *const MSID_OAUTH2_EXPIRES_IN         = @"expires_in";
NSString *const MSID_OAUTH2_GRANT_TYPE         = @"grant_type";
NSString *const MSID_OAUTH2_REDIRECT_URI       = @"redirect_uri";
NSString *const MSID_OAUTH2_REFRESH_TOKEN      = @"refresh_token";
NSString *const MSID_OAUTH2_RESOURCE           = @"resource";
NSString *const MSID_OAUTH2_RESPONSE_TYPE      = @"response_type";
NSString *const MSID_OAUTH2_SCOPE              = @"scope";
NSString *const MSID_OAUTH2_STATE              = @"state";
NSString *const MSID_OAUTH2_SUB_ERROR          = @"sub_error";
NSString *const MSID_OAUTH2_TOKEN              = @"token";
NSString *const MSID_OAUTH2_INSTANCE_DISCOVERY_SUFFIX = @"common/discovery/instance";
NSString *const MSID_OAUTH2_TOKEN_TYPE         = @"token_type";
NSString *const MSID_OAUTH2_LOGIN_HINT         = @"login_hint";
NSString *const MSID_OAUTH2_ID_TOKEN           = @"id_token";
NSString *const MSID_OAUTH2_CORRELATION_ID_RESPONSE  = @"correlation_id";
NSString *const MSID_OAUTH2_CORRELATION_ID_REQUEST   = @"return-client-request-id";
NSString *const MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE = @"client-request-id";
NSString *const MSID_OAUTH2_ASSERTION = @"assertion";
NSString *const MSID_OAUTH2_SAML11_BEARER_VALUE = @"urn:ietf:params:oauth:grant-type:saml1_1-bearer";
NSString *const MSID_OAUTH2_SAML2_BEARER_VALUE = @"urn:ietf:params:oauth:grant-type:saml2-bearer";
NSString *const MSID_OAUTH2_SCOPE_OPENID_VALUE = @"openid";
NSString *const MSID_OAUTH2_CLIENT_TELEMETRY    = @"x-ms-clitelem";
NSString *const MSID_OAUTH2_PROMPT              = @"prompt";
NSString *const MSID_OAUTH2_PROMPT_NONE         = @"none";

NSString *const MSID_OAUTH2_EXPIRES_ON          = @"expires_on";
NSString *const MSID_OAUTH2_EXT_EXPIRES_IN      = @"ext_expires_in";
NSString *const MSID_FAMILY_ID                  = @"foci";

NSString *const MSID_OAUTH2_CODE_CHALLENGE               = @"code_challenge";
NSString *const MSID_OAUTH2_CODE_CHALLENGE_METHOD        = @"code_challenge_method";
NSString *const MSID_OAUTH2_CODE_VERIFIER                = @"code_verifier";

NSString *const MSID_OAUTH2_CLIENT_INFO                  = @"client_info";
NSString *const MSID_OAUTH2_UNIQUE_IDENTIFIER            = @"uid";
NSString *const MSID_OAUTH2_UNIQUE_TENANT_IDENTIFIER     = @"utid";

NSString *const MSID_OAUTH2_DOMAIN_REQ                   = @"domain_req";
NSString *const MSID_OAUTH2_LOGIN_REQ                    = @"login_req";

NSString *const MSID_OAUTH2_ADDITIONAL_SERVER_INFO       = @"additional_server_info";
NSString *const MSID_OAUTH2_ENVIRONMENT                  = @"environment";

NSString *const MSID_CREDENTIAL_TYPE_CACHE_KEY           = @"credential_type";
NSString *const MSID_ENVIRONMENT_CACHE_KEY               = @"environment";
NSString *const MSID_REALM_CACHE_KEY                     = @"realm";
NSString *const MSID_AUTHORITY_CACHE_KEY                 = @"authority";
NSString *const MSID_UNIQUE_ID_CACHE_KEY                 = @"unique_user_id";
NSString *const MSID_CLIENT_ID_CACHE_KEY                 = @"client_id";
NSString *const MSID_FAMILY_ID_CACHE_KEY                 = @"family_id";
NSString *const MSID_TOKEN_CACHE_KEY                     = @"secret";
NSString *const MSID_USERNAME_CACHE_KEY                  = @"username";
NSString *const MSID_TARGET_CACHE_KEY                    = @"target";
NSString *const MSID_CLIENT_INFO_CACHE_KEY               = @"client_info";
NSString *const MSID_ID_TOKEN_CACHE_KEY                  = @"id_token";
NSString *const MSID_ADDITIONAL_INFO_CACHE_KEY           = @"additional_info";
NSString *const MSID_EXPIRES_ON_CACHE_KEY                = @"expires_on";
NSString *const MSID_OAUTH_TOKEN_TYPE_CACHE_KEY          = @"access_token_type";
NSString *const MSID_EXTENDED_EXPIRES_ON_CACHE_KEY       = @"extended_expires_on";
NSString *const MSID_CACHED_AT_CACHE_KEY                 = @"cached_at";
NSString *const MSID_EXTENDED_EXPIRES_ON_LEGACY_CACHE_KEY       = @"ext_expires_on";
NSString *const MSID_SPE_INFO_CACHE_KEY                  = @"spe_info";
NSString *const MSID_RESOURCE_RT_CACHE_KEY               = @"resource_refresh_token";
NSString *const MSID_ACCOUNT_ID_CACHE_KEY                = @"authority_account_id";
NSString *const MSID_AUTHORITY_TYPE_CACHE_KEY            = @"authority_type";
NSString *const MSID_FIRST_NAME_CACHE_KEY                = @"first_name";
NSString *const MSID_LAST_NAME_CACHE_KEY                 = @"last_name";

NSString *const MSID_ACCESS_TOKEN_CACHE_TYPE             = @"accesstoken";
NSString *const MSID_REFRESH_TOKEN_CACHE_TYPE            = @"refreshtoken";
NSString *const MSID_LEGACY_TOKEN_CACHE_TYPE             = @"legacysingleresourcetoken";
NSString *const MSID_ID_TOKEN_CACHE_TYPE                 = @"idtoken";
NSString *const MSID_GENERAL_TOKEN_CACHE_TYPE            = @"token";

NSString *MSID_OAUTH2_AUTHORIZE_SUFFIX(void)
{
    __auto_type apiVersion = MSIDConfiguration.defaultConfiguration.aadApiVersion;

    return [NSString stringWithFormat:@"/oauth2/%@%@authorize", apiVersion ?: @"", apiVersion ? @"/" : @""];
}

NSString *MSID_OAUTH2_TOKEN_SUFFIX(void)
{
    __auto_type apiVersion = MSIDConfiguration.defaultConfiguration.aadApiVersion;
    
    return [NSString stringWithFormat:@"/oauth2/%@%@token", apiVersion ?: @"", apiVersion ? @"/" : @""];
}
