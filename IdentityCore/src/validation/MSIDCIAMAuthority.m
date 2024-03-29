//
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

#if !EXCLUDE_FROM_MSALCPP

#import "MSIDCIAMAuthority.h"
#import "MSIDCIAMAuthorityResolver.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializableTypes.h"
#import "MSIDProviderType.h"
#import "MSIDAADTenant.h"
#import "MSIDAADAuthority.h"
#import "NSString+MSIDExtensions.h"

@implementation MSIDCIAMAuthority

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:MSID_JSON_TYPE_CIAM_AUTHORITY];
    [MSIDJsonSerializableFactory mapJSONKey:MSID_PROVIDER_TYPE_JSON_KEY keyValue:MSID_JSON_TYPE_PROVIDER_CIAM kindOfClass:MSIDAuthority.class toClassType:MSID_JSON_TYPE_CIAM_AUTHORITY];
}

- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                      validateFormat:(BOOL)validateFormat
                           rawTenant:(nullable NSString *)rawTenant
                             context:(nullable id<MSIDRequestContext>)context
                               error:(NSError **)error
{    
    self = [self initWithURL:url validateFormat:validateFormat context:context error:error];
    if (self)
    {
        if (rawTenant)
        {
            if ([self.class isAuthorityFormatValid:url context:context error:nil])
            {
                _url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", [url msidHostWithPortIfNecessary], rawTenant]];
                _realm = rawTenant;
            }
        }
    }

    return self;
}

- (nullable instancetype)initWithURL:(NSURL *)url
                      validateFormat:(BOOL)validateFormat
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    self = [super initWithURL:url validateFormat:validateFormat context:context error:error];
    
    NSArray *hostComponents = [url.msidHostWithPortIfNecessary componentsSeparatedByString:@"."];
    
    //If we have the URL https://tenant.ciamlogin.com or https://tenant.ciamlogin.com/
    if (url.pathComponents.count == 0 || ((url.pathComponents.count == 1) && [[url lastPathComponent] isEqual:@"/"]))
    {
        url = [url URLByAppendingPathComponent:hostComponents[0]];
        url = [NSURL URLWithString:[url.absoluteString stringByAppendingString:@".onmicrosoft.com"]];
    }
   
    if (self)
    {
        _url = [MSIDAADAuthority normalizedAuthorityUrl:url context:context error:error];
        if (!_url) return nil;
        self.url = url;
    }
    
    return self;
}
    
- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    return [self initWithURL:url validateFormat:YES context:context error:error];
}

+ (BOOL)isAuthorityFormatValid:(NSURL *)url
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (![super isAuthorityFormatValid:url context:context error:error]) return NO;
    
    NSArray *hostComponents = [url.msidHostWithPortIfNecessary componentsSeparatedByString:@"."];
    
    if (hostComponents.count < 3)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"CIAM authority should have at least 3 segments in the path (i.e. https://<tenant>.ciamlogin.com...)", nil, nil, nil, context.correlationId, nil, YES);
        }
        
        return NO;
    }
    
    NSString *ciamTenant = hostComponents[1];
    
    if (![ciamTenant.lowercaseString isEqualToString:@"ciamlogin".lowercaseString])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"It is not CIAM authority.", nil, nil, nil, context.correlationId, nil, YES);
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)supportsBrokeredAuthentication
{
    return NO;
}

- (BOOL)excludeFromAuthorityValidation
{
    return YES;
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    MSIDCIAMAuthority *authority = [super copyWithZone:zone];
    return authority;
}

- (id<MSIDAuthorityResolving>)resolver
{
    return [MSIDCIAMAuthorityResolver new];
}

- (nonnull NSString *)telemetryAuthorityType
{
#if !EXCLUDE_FROM_MSALCPP
    return MSID_TELEMETRY_VALUE_AUTHORITY_CIAM;
#else // MSAL CPP
    return @"";
#endif
}

#pragma mark - Private
+ (NSString *)realmFromURL:(NSURL *)url
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    //If there is a path component, return it, else return just URL
    if ([self isAuthorityFormatValid:url context:context error:error] && url.pathComponents.count > 1)
    {
        return url.pathComponents[1];
    }

    // We do support non standard CIAM authority formats
    return url.path;
}

@end
#endif
