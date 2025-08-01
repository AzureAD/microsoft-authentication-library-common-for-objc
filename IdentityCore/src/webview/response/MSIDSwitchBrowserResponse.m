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


#import "MSIDSwitchBrowserResponse.h"
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDConstants.h"
#import "MSIDFlightManager.h"
#import "NSData+MSIDExtensions.h"

@implementation MSIDSwitchBrowserResponse

+ (NSString *)operation
{
    return MSID_BROWSER_RESPONSE_SWITCH_BROWSER;
}

- (instancetype)initWithURL:(NSURL *)url
                redirectUri:(NSString *)redirectUri
               requestState:(NSString *)requestState
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    self = [super initWithURL:url
                      context:context
                        error:error];
    
    if (self)
    {
        if (![self isMyUrl:url redirectUri:redirectUri]) return nil;
        
        if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_SUPPORT_STATE_DUNA_CBA])
        {
            NSError *stateCheckError = nil;
            BOOL stateValidated = [MSIDSwitchBrowserResponse validateStateParameter:self.parameters[MSID_OAUTH2_STATE]
                                                                      expectedState:requestState
                                                                              error:&stateCheckError];
            if (!stateValidated)
            {
                if (stateCheckError && error)
                {
                    *error = stateCheckError;
                }
                return nil;
            }
        }
        
        _actionUri = self.parameters[@"action_uri"];
        _useEphemeralWebBrowserSession = YES;
        _state = self.parameters[MSID_OAUTH2_STATE];
        
        NSString* browserOptionsString = self.parameters[@"browser_modes"];
        if (browserOptionsString)
        {
            NSData *data = [NSData msidDataFromBase64UrlEncodedString:browserOptionsString];
            uint32_t flagsValue = 0;
            [data getBytes:&flagsValue length:sizeof(flagsValue)];
            
            MSIDSwitchBrowserModes modes = (MSIDSwitchBrowserModes)flagsValue;
            _useEphemeralWebBrowserSession = modes & BrowserModePrivateSession;
        }
        
        if ([NSString msidIsStringNilOrBlank:_actionUri])
        {
            if (error) *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerInvalidResponse, @"action_uri is nil.", nil, nil, nil, context.correlationId, nil, YES);
            return nil;
        }
        
        _switchBrowserSessionToken = self.parameters[MSID_OAUTH2_CODE];
        if ([NSString msidIsStringNilOrBlank:_switchBrowserSessionToken])
        {
            if (error) *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerInvalidResponse, @"code is nil.", nil, nil, nil, context.correlationId, nil, YES);
            return nil;
        }
    }
    
    return self;
}

- (BOOL)useV2WebResponseHandling
{
    BOOL useV2WebResponseHandling = [super useV2WebResponseHandling];
        useV2WebResponseHandling |= [MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_SUPPORT_DUNA_CBA];
    
    return useV2WebResponseHandling;
}

+ (BOOL)isDUNAActionUrl:(NSURL *)url operation:(NSString *)operation
{
    if (url == nil) return NO;
    
    NSArray *pathComponents = url.pathComponents;
    if ([pathComponents count] < 2)
    {
        return NO;
    }
    
    if ([pathComponents[1] isEqualToString:operation])
    {
        return YES;
    }
    
    return NO;
}

+ (BOOL)validateStateParameter:(NSString *)receivedState
                 expectedState:(NSString *)expectedState
                         error:(NSError *__autoreleasing*)error
{
    if (!receivedState && !expectedState)
    {
        return YES;
    }
    
    if (!expectedState || !receivedState)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidState,
                                     [NSString stringWithFormat:@"Missing or invalid state returned state: %@", receivedState],
                                     nil, nil, nil, nil, nil, YES);
        }
        return NO;
    }
    
    BOOL result = [receivedState.msidBase64UrlDecode isEqualToString:expectedState];
    
    if (!result)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"State parameter mismatch");
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidState,
                                     [NSString stringWithFormat:@"State parameter mismatch. Expected: %@, Received: %@", expectedState, receivedState],
                                     nil, nil, nil, nil, nil, YES);
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Private

- (BOOL)isMyUrl:(NSURL *)url
    redirectUri:(NSString *)redirectUri
{
    if (url == nil) return NO;
    if ([NSString msidIsStringNilOrBlank:redirectUri]) return NO;
    
    NSURL *redirectUrl = [[NSURL alloc] initWithString:redirectUri];
    if (!redirectUrl) return NO;
    
    // msauth://<broker id>/switch_browser?action_uri=(not-null)&code=(not-null)
    // msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=(not-null)&code=(not-null)
    NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    urlComponents.query = nil;
    urlComponents.path = nil;
    urlComponents.fragment = nil;
    
    NSURLComponents *redirectUrlComponents = [[NSURLComponents alloc] initWithURL:redirectUrl resolvingAgainstBaseURL:NO];
    redirectUrlComponents.query = nil;
    redirectUrlComponents.path = nil;
    redirectUrlComponents.fragment = nil;

    if (![urlComponents.string.lowercaseString isEqualToString:redirectUrlComponents.string.lowercaseString])
    {
        return NO;
    }
    
    return [self.class isDUNAActionUrl:url operation:[self.class operation]];
}

@end
