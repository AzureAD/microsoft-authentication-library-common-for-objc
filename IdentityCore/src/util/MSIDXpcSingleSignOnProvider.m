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

#define requireIsAPPLSignedAnchor    "anchor apple generic"

#define requireIsAPPLSignedExternal "certificate 1[field.1.2.840.113635.100.6.2.6] exists"
#define requireIsMSFTSignedExternal "certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = UBF8T346G9"

#define coreRequirementExternal "(" requireIsAPPLSignedExternal    ") and (" requireIsMSFTSignedExternal ")"

// For App Store, Microsoft certificates don't show up in certificate chain.
// Instead, we check for the app to be Microsoft App Group.
#define requireIsAppStoreSigned        "certificate leaf[field.1.2.840.113635.100.6.1.9] exists"
#define requireBelongsToMSFTAppGroup "entitlement[\"com.apple.security.application-groups\"] = \"UBF8T346G9.\"*"

#define coreRequirementAppStore "(" requireIsAppStoreSigned ") and (" requireBelongsToMSFTAppGroup ")"

#define distributionRequirement "(" requireIsAPPLSignedAnchor ") and ((" coreRequirementAppStore ") or (" coreRequirementExternal "))"

// For internal builds only we also recognize dev builds but exclude them from external builds
// for sake of simplicity and performance

#define requireIsAPPLSignedInternal "certificate 1[field.1.2.840.113635.100.6.2.1] exists"
#define requireIsMSFTSignedInternal "certificate leaf[subject.CN] = \"%@\""

// requireIsXctestApp comes from the generated XctestCodeRequirement.h above
#define coreRequirementInternal "((" requireIsAPPLSignedInternal ") and (" requireIsMSFTSignedInternal "))"

#define developmentRequirement "(" requireIsAPPLSignedAnchor ") and ((" coreRequirementAppStore ") or (" coreRequirementExternal ") or (" coreRequirementInternal "))"

#import "MSIDXpcSingleSignOnProvider.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDBrokerCryptoProvider.h"
#import "MSIDBrokerConstants.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDBrokerOperationTokenResponse.h"

@protocol MSIDXpcBrokerInstanceProtocol <NSObject>

- (void)handleXpcWithRequestParams:(NSDictionary *)passedInParams
                                   parentViewFrame:(NSRect)frame
                                   completionBlock:(void (^)(NSDictionary<NSString *,id> * _Nonnull, NSDate * _Nonnull, NSString * _Nonnull, NSError * _Nullable))blockName;

@end

@protocol MSIDXpcBrokerDispatcherProtocol <NSObject>

- (void)getBrokerInstanceEndpointWithRequestInfo:(NSDictionary <NSString *, id> * _Nullable)requestInfo
                                           reply:(void (^)(NSXPCListenerEndpoint  * _Nullable listenerEndpoint, NSDictionary * _Nullable params, NSError * _Nullable error))reply;
@end

typedef void (^NSXPCListenerEndpointCompletionBlock)(id<MSIDXpcBrokerInstanceProtocol> _Nullable xpcService, NSXPCConnection  * _Nullable directConnection, NSError *error);

static NSString *machServiceName = @"UBF8T346G9.com.microsoft.entrabroker.EntraIdentityBrokerXPC.Mach";
static NSString *brokerDispatcher = @"com.microsoft.entrabroker.BrokerApp";
static NSString *brokerInstance = @"com.microsoft.EntraIdentityBroker.Service";

@implementation MSIDXpcSingleSignOnProvider

- (void)handleRequestParam:(NSDictionary *)requestParam
                 brokerKey:brokerKey
 assertKindOfResponseClass:(Class)aClass
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock
{
    [self handleRequestParam:requestParam
             parentViewFrame:CGRectZero
                   brokerKey:brokerKey
   assertKindOfResponseClass:(Class)aClass
               continueBlock:continueBlock];
}

- (void)handleRequestParam:(NSDictionary *)requestParam
           parentViewFrame:(NSRect)frame
                 brokerKey:brokerKey
 assertKindOfResponseClass:(Class)aClass
             continueBlock:(MSIDSSOExtensionRequestDelegateCompletionBlock)continueBlock
{
    [self getXpcService:^(id<MSIDXpcBrokerInstanceProtocol> xpcService, NSXPCConnection *directConnection, NSError *error) {
        if (!xpcService || error)
        {
            if (continueBlock) continueBlock(nil, error);
            return;
        }
        
        [xpcService handleXpcWithRequestParams:requestParam parentViewFrame:frame completionBlock:^(NSDictionary<NSString *,id> * _Nonnull replyParam, NSDate * _Nonnull __unused xpcStartDate, NSString * _Nonnull __unused processId, NSError * _Nonnull callbackError) {
            [directConnection suspend];
            [directConnection invalidate];
            MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:[NSData msidDataFromBase64UrlEncodedString:brokerKey]];
            NSDictionary *jsonResponse = [cryptoProvider decryptBrokerResponse:replyParam correlationId:nil error:nil];
            
            BOOL forceRunOnBackgroundQueue = [[jsonResponse objectForKey:MSID_BROKER_OPERATION_KEY] isEqualToString:@"refresh"];
            [self forceRunOnBackgroundQueue:forceRunOnBackgroundQueue dispatchBlock:^{
                if (callbackError)
                {
                    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"[Entra broker] CLIENT received operationResponse with error: %@", callbackError);
                    if (continueBlock) continueBlock(nil, callbackError);
                    return;
                }
                
                NSError *innerError = nil;
                __auto_type operationResponse = (MSIDBrokerOperationTokenResponse *)[MSIDJsonSerializableFactory createFromJSONDictionary:jsonResponse classTypeJSONKey:MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY assertKindOfClass:aClass error:&innerError];

                if (!operationResponse)
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Entra broker] CLIENT cannot create operationResponse");
                    if (continueBlock) continueBlock(nil, innerError);
                }
                else
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Entra broker] CLIENT received operationResponse, error: %@", callbackError);
                    if (continueBlock) continueBlock(operationResponse, callbackError);
                }
            }];
        }];
    }];
}

#pragma mark - Helpers

- (NSString *)codeSignRequirementForBundleId:(NSString *)bundleId devIdentity:(NSString *)devIdentity
{
#if DEBUG
    NSString *codeSignFormat = [NSString stringWithCString:developmentRequirement encoding:NSUTF8StringEncoding];
    NSString *baseRequirementWithDevIdentity = [NSString stringWithFormat:codeSignFormat, devIdentity];
    NSString *stringWithAdditionalRequirements = [NSString stringWithFormat:@"(identifier \"%@\") and %@"
                        " and !(entitlement[\"com.apple.security.cs.allow-dyld-environment-variables\"] /* exists */)"
                        " and !(entitlement[\"com.apple.security.cs.disable-library-validation\"] /* exists */)"
                        " and !(entitlement[\"com.apple.security.cs.allow-unsigned-executable-memory\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-jit\"] /* exists */)", bundleId, baseRequirementWithDevIdentity];
#else
    NSString *baseRequirementWithDevIdentity = [NSString stringWithCString:distributionRequirement encoding:NSUTF8StringEncoding];
    NSString *stringWithAdditionalRequirements = [NSString stringWithFormat:@"(identifier \"%@\") and %@"
                        " and !(entitlement[\"com.apple.security.cs.allow-dyld-environment-variables\"] /* exists */)"
                        " and !(entitlement[\"com.apple.security.cs.disable-library-validation\"] /* exists */)"
                        " and !(entitlement[\"com.apple.security.cs.allow-unsigned-executable-memory\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-jit\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.get-task-allow\"] /* exists */)" , bundleId, baseRequirementWithDevIdentity];
#endif
    
    return stringWithAdditionalRequirements;
}

- (NSString *)signingIdentity
{
    SecCodeRef selfCode = NULL;
    OSStatus status = SecCodeCopySelf(kSecCSDefaultFlags, &selfCode);
    
    if (!selfCode)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Failed to copy signing information", nil, nil);
        return nil;
    }
    
    CFDictionaryRef cfDic = NULL;
    status = SecCodeCopySigningInformation(selfCode, kSecCSSigningInformation, &cfDic);
    
    if (!cfDic)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Failed to copy signing dictionary", nil, nil);
        CFRelease(selfCode);
        return nil;
    }
    
    NSDictionary *signingDic = CFBridgingRelease(cfDic);
    CFRelease(selfCode);
    
    return [self devSigningIdentityFromSigningDictionary:signingDic];
}

- (NSString *)devSigningIdentityFromSigningDictionary:(NSDictionary *)signingDic
{
    NSArray *signingCertificates = signingDic[@"certificates"];
    
    if (!signingCertificates
        || ![signingCertificates isKindOfClass:[NSArray class]]
        || ![signingCertificates count])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"No certificates present in the signing dictionary", nil, nil);
        return nil;
    }
    
    SecCertificateRef leafCert = (__bridge SecCertificateRef)(signingCertificates[0]);
    CFStringRef certCommonName = NULL;
    OSStatus status = SecCertificateCopyCommonName(leafCert, &certCommonName);
    
    if (!certCommonName)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, [NSString stringWithFormat:@"Error with code %ld, description %@", (long)status, @"Failed to copy certificate common name"], nil, nil);
        return nil;
    }
    
    return CFBridgingRelease(certCommonName);
}

- (void)forceRunOnBackgroundQueue:(BOOL)forceOnBackgroundQueue dispatchBlock:(void (^)(void))dispatchBlock
{
    if (forceOnBackgroundQueue && [NSThread isMainThread])
    {
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            dispatchBlock();
        });
    }
    else
    {
        dispatchBlock();
    }
}

- (void)getXpcService:(NSXPCListenerEndpointCompletionBlock)continueBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT - started establishing connection");
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:machServiceName options:0];
    
    NSString *codeSigningRequirement = [self codeSignRequirementForBundleId:brokerDispatcher devIdentity:[self signingIdentity]];
    
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MSIDXpcBrokerDispatcherProtocol)];
    if (@available(macOS 13.0, *)) {
        [connection setCodeSigningRequirement:codeSigningRequirement];
    } else {
        // Fallback on earlier versions
    }
    [connection resume];
    
    [connection setInterruptionHandler:^{
        NSError *xpcUnexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorSSOExtensionUnexpectedError, @"[Entra broker] CLIENT -- dispatcher connection is interrupted", nil, nil, nil, nil, nil, YES);
        if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
    }];
    
    id<MSIDXpcBrokerDispatcherProtocol> parentXpcService = [connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSError *xpcUnexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorSSOExtensionUnexpectedError, [NSString stringWithFormat:@"[Entra broker] CLIENT -- failed to connect to dispatcher, error: %@", error], nil, nil, nil, nil, nil, YES);
        if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
    }];
    
    [parentXpcService getBrokerInstanceEndpointWithRequestInfo:@{} reply:^(NSXPCListenerEndpoint * _Nullable listenerEndpoint, NSDictionary<NSString *, id> * _Nullable __unused params, NSError * _Nullable error) {
        
        [connection suspend];
        [connection invalidate];
        if (error)
        {
            NSError *xpcUnexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorSSOExtensionUnexpectedError, [NSString stringWithFormat:@"[Entra broker] CLIENT - get broker instance endpoint failed: %@", error], nil, nil, nil, nil, nil, YES);
            if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
            return;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Entra broker] CLIENT - connected to new service endpoint %@", listenerEndpoint);
        NSXPCConnection *directConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:listenerEndpoint];
        directConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MSIDXpcBrokerInstanceProtocol)];

        NSString *clientCodeSigningRequirement = [self codeSignRequirementForBundleId:brokerInstance devIdentity:[self signingIdentity]];

        if (@available(macOS 13.0, *)) {
            [directConnection setCodeSigningRequirement:clientCodeSigningRequirement];
        } else {
            // Fallback on earlier versions
        }
        [directConnection resume];
        
        [directConnection setInterruptionHandler:^{
            NSError *xpcUnexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorSSOExtensionUnexpectedError, @"[Entra broker] CLIENT -- instance connection is interrupted", nil, nil, nil, nil, nil, YES);
            if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
        }];
        
        id<MSIDXpcBrokerInstanceProtocol> directService = [directConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull callbackError) {
            NSError *xpcUnexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorSSOExtensionUnexpectedError, [NSString stringWithFormat:@"[Entra broker] CLIENT -- failed to connect to instance, error: %@", callbackError], nil, nil, nil, nil, nil, YES);
            if (continueBlock) continueBlock(nil, nil, xpcUnexpectedError);
        }];
        
        if (continueBlock) continueBlock(directService, directConnection, nil);
    }];
}

@end
