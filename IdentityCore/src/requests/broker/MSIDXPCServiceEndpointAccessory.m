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

#import "MSIDXPCServiceEndpointAccessory.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDBrokerCryptoProvider.h"
#import "MSIDBrokerConstants.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDBrokerOperationTokenResponse.h"

static NSXPCListenerEndpoint * s_listenerEndpoint = nil;

@interface MSIDXPCServiceEndpointAccessory()

@property (nonatomic) dispatch_queue_t synchronizationQueue;
@property (nonatomic) NSXPCConnection *directConnection;
@property (nonatomic, strong) NSTimer *myTimer;
@property (nonatomic) BOOL shoudlReconnect;
@property (nonatomic, copy) NSXPCListenerEndpointTearDownBlock tearDownBlock;

@end

@implementation MSIDXPCServiceEndpointAccessory

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.xpcservice-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
        _shoudlReconnect = YES;
    }
    
    return self;
        
}

- (void)getXpcService:(NSXPCListenerEndpointTearDownBlock)continueblock
{
    NSLog(@"[Entra broker] CLIENT - started establishing connection %f", [[NSDate date] timeIntervalSince1970]);
    
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:@"UBF8T346G9.com.microsoft.entrabroker.EntraIdentityBrokerXPC.Mach" options:0];
    
    
    NSString *codeSigningRequirement = [self codeSignRequirementForBundleId:@"com.microsoft.entrabroker.BrokerApp" devIdentity:@"Apple Development: Kai Song (4C4WFUGLAB)"];
    
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ADBParentXPCServiceProtocol)];
    if (@available(macOS 13.0, *)) {
        [connection setCodeSigningRequirement:codeSigningRequirement];
    } else {
        // Fallback on earlier versions
    }
    [connection resume];
    
    [connection setInvalidationHandler:^{
        NSLog(@"[Entra broker] CLIENT agent Connection invalidated");
    }];
    
    [connection setInterruptionHandler:^{
        NSLog(@"[Entra broker] CLIENT agent Connection interrupted");
    }];
    
    id<ADBParentXPCServiceProtocol> parentXpcService = [connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSLog(@"[Entra broker] CLIENT agent has error %@", error);
        // TODO: handle error
    }];
    [parentXpcService getBrokerInstanceEndpointWithRequestInfo:@{} reply:^(NSXPCListenerEndpoint * _Nullable listenerEndpoint, NSDictionary<NSString *, id> * _Nullable __unused params, NSError * _Nullable error) {
        if (error)
        {
            NSLog(@"[Entra broker] CLIENT - get broker instance endpoint failed: %@", error);
            return;
        }
        
        NSLog(@"[Entra broker] CLIENT - connected to new service endpoint %@", listenerEndpoint);

        NSXPCConnection *directConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:listenerEndpoint];
        directConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ADBChildBrokerProtocol)];

        NSString *clientCodeSigningRequirement = [self codeSignRequirementForBundleId:@"com.microsoft.EntraIdentityBroker.Service" devIdentity:@"Apple Development: Kai Song (4C4WFUGLAB)"];

        if (@available(macOS 13.0, *)) {
            [directConnection setCodeSigningRequirement:clientCodeSigningRequirement];
        } else {
            // Fallback on earlier versions
        }
        [directConnection resume];

        id<ADBChildBrokerProtocol> directService = [directConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull callbackError) {
            NSLog(@"[Entra broker] CLIENT - received direct service error %@", callbackError);
        }];
        continueblock(directService);
    }];
}

- (NSString *)codeSignRequirementForBundleId:(NSString *)bundleId devIdentity:(NSString *)devIdentity
{
    // TODO: modify this for distribution. MSAL code should always talk to distribution signed agent only, and we can enable dev signed agent for MS_INTERNAL macro only
    
    NSString *baseRequirementWithDevIdentity = [NSString stringWithFormat:@developmentRequirement, devIdentity];
    NSString *stringWithAdditionalRequirements = [NSString stringWithFormat:@"(identifier \"%@\") and %@"
                        " and !(entitlement[\"com.apple.security.cs.allow-dyld-environment-variables\"] /* exists */)"
                        " and !(entitlement[\"com.apple.security.cs.disable-library-validation\"] /* exists */)"
                        " and !(entitlement[\"com.apple.security.cs.allow-unsigned-executable-memory\"] /* exists */)"
                                                  " and !(entitlement[\"com.apple.security.cs.allow-jit\"] /* exists */)", bundleId, baseRequirementWithDevIdentity];
    
    
    // TODO: add this for distribution to prohibit debugger
    //" and !(entitlement[\"com.apple.security.get-task-allow\"] /* exists */)"
    return stringWithAdditionalRequirements;
}

- (void)handleRequestParam:(NSDictionary *)requestParam
                 brokerKey:(id)brokerKey
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
    [self getXpcService:^(id<ADBChildBrokerProtocol>  _Nonnull xpcService) {
        [xpcService handleXpcWithRequestParams:requestParam parentViewFrame:frame completionBlock:^(NSDictionary<NSString *,id> * _Nonnull replyParam, NSDate * _Nonnull __unused xpcStartDate, NSString * _Nonnull __unused processId, NSError * _Nonnull error) {
            MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:[NSData msidDataFromBase64UrlEncodedString:brokerKey]];
            NSDictionary *jsonResponse = [cryptoProvider decryptBrokerResponse:replyParam correlationId:nil error:nil];
            
            BOOL forceRunOnBackgroundQueue = [[jsonResponse objectForKey:MSID_BROKER_OPERATION_KEY] isEqualToString:@"refresh"];
            [self forceRunOnBackgroundQueue:forceRunOnBackgroundQueue dispatchBlock:^{
                if (error)
                {
                    NSLog(@"[Entra broker] CLIENT Time spent, received operationResponse with error: %@", error.description);
                    continueBlock(nil, error);
                    return;
                }
                NSError *innerError = nil;
                __auto_type operationResponse = (MSIDBrokerOperationTokenResponse *)[MSIDJsonSerializableFactory createFromJSONDictionary:jsonResponse classTypeJSONKey:MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY assertKindOfClass:aClass error:&innerError];

                if (!operationResponse)
                {
                    NSLog(@"[Entra broker] cannot create operationResponse");
                    continueBlock(nil, innerError);
                }
                else
                {
                    NSLog(@"[Entra broker] CLIENT Time spent, received operationResponse");
                    continueBlock(operationResponse, error);
                }
            }];
        }];
    }];
}

- (void)forceRunOnBackgroundQueue:(BOOL)forceOnBackgroundQueue dispatchBlock:(void (^)(void))dispatchBlock {
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

@end
