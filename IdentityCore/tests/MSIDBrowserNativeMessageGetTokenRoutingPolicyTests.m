//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDBrowserNativeMessageGetTokenRoutingPolicy.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDBrowserNativeMessageGetTokenRoutingPolicyTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageGetTokenRoutingPolicyTests

- (void)testRoute_defaultPromptWithEligibleAccount_returnsSilent
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                            homeAccountId:@"uid.utid"];

    MSIDBrowserNativeMessageGetTokenRoute route =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:NO
                                                                  promptType:MSIDPromptTypePromptIfNecessary
                                                                   canShowUI:NO
                                                            accountIdentifier:account
                                                       requiresHomeAccountId:YES];

    XCTAssertEqual(route, MSIDBrowserNativeMessageGetTokenRouteSilent);
}

- (void)testRoute_postSilentFallbackWithUI_returnsInteractive
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                            homeAccountId:@"uid.utid"];

    MSIDBrowserNativeMessageGetTokenRoute route =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:YES
                                                                  promptType:MSIDPromptTypePromptIfNecessary
                                                                   canShowUI:YES
                                                            accountIdentifier:account
                                                       requiresHomeAccountId:YES];

    XCTAssertEqual(route, MSIDBrowserNativeMessageGetTokenRouteInteractive);
}

- (void)testRoute_postSilentFallbackWithoutUI_returnsUIBlocked
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                            homeAccountId:@"uid.utid"];

    MSIDBrowserNativeMessageGetTokenRoute route =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:YES
                                                                  promptType:MSIDPromptTypePromptIfNecessary
                                                                   canShowUI:NO
                                                            accountIdentifier:account
                                                       requiresHomeAccountId:YES];

    XCTAssertEqual(route, MSIDBrowserNativeMessageGetTokenRouteUIBlocked);
}

- (void)testRoute_promptNeverAfterSilentFailure_returnsInteractionRequired
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                            homeAccountId:@"uid.utid"];

    MSIDBrowserNativeMessageGetTokenRoute route =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:YES
                                                                  promptType:MSIDPromptTypeNever
                                                                   canShowUI:YES
                                                            accountIdentifier:account
                                                       requiresHomeAccountId:YES];

    XCTAssertEqual(route, MSIDBrowserNativeMessageGetTokenRouteInteractionRequired);
}

- (void)testRoute_interactivePromptWithoutUI_returnsUIBlocked
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                            homeAccountId:@"uid.utid"];

    MSIDBrowserNativeMessageGetTokenRoute route =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:NO
                                                                  promptType:MSIDPromptTypeLogin
                                                                   canShowUI:NO
                                                            accountIdentifier:account
                                                       requiresHomeAccountId:YES];

    XCTAssertEqual(route, MSIDBrowserNativeMessageGetTokenRouteUIBlocked);
}

- (void)testRoute_displayableIdOnly_preservesCallerHomeAccountRequirement
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                            homeAccountId:nil];

    MSIDBrowserNativeMessageGetTokenRoute providerRoute =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:NO
                                                                  promptType:MSIDPromptTypePromptIfNecessary
                                                                   canShowUI:YES
                                                            accountIdentifier:account
                                                       requiresHomeAccountId:NO];
    MSIDBrowserNativeMessageGetTokenRoute brokerNonStsRoute =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:NO
                                                                  promptType:MSIDPromptTypePromptIfNecessary
                                                                   canShowUI:YES
                                                            accountIdentifier:account
                                                       requiresHomeAccountId:YES];

    XCTAssertEqual(providerRoute, MSIDBrowserNativeMessageGetTokenRouteSilent);
    XCTAssertEqual(brokerNonStsRoute, MSIDBrowserNativeMessageGetTokenRouteInteractive);
}

- (void)testRoute_missingAccountAndPromptNever_returnsInteractionRequired
{
    MSIDBrowserNativeMessageGetTokenRoute route =
    [MSIDBrowserNativeMessageGetTokenRoutingPolicy routeWithForceInteractive:NO
                                                                  promptType:MSIDPromptTypeNever
                                                                   canShowUI:YES
                                                            accountIdentifier:nil
                                                       requiresHomeAccountId:NO];

    XCTAssertEqual(route, MSIDBrowserNativeMessageGetTokenRouteInteractionRequired);
}

- (void)testShouldAttemptSilent_stsWithUpnOnly_returnsYes
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                            homeAccountId:nil];

    XCTAssertTrue([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                               promptType:MSIDPromptTypeNever
                                                                                        accountIdentifier:account
                                                                                   requiresHomeAccountId:NO]);
}

- (void)testShouldAttemptSilent_nonStsWithUpnOnly_returnsNo
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                            homeAccountId:nil];

    XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                                promptType:MSIDPromptTypePromptIfNecessary
                                                                                         accountIdentifier:account
                                                                                    requiresHomeAccountId:YES]);
}

- (void)testShouldAttemptSilent_nonStsWithHomeAccountId_returnsYes
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                            homeAccountId:@"uid.utid"];

    XCTAssertTrue([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                               promptType:MSIDPromptTypePromptIfNecessary
                                                                                        accountIdentifier:account
                                                                                   requiresHomeAccountId:YES]);
}

- (void)testShouldAttemptSilent_forceInteractiveOrInteractivePromptOrMissingAccount_returnsNo
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil
                                                                            homeAccountId:@"uid.utid"];

    XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:YES
                                                                                                promptType:MSIDPromptTypeNever
                                                                                         accountIdentifier:account
                                                                                    requiresHomeAccountId:YES]);
    XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                                promptType:MSIDPromptTypeLogin
                                                                                         accountIdentifier:account
                                                                                    requiresHomeAccountId:YES]);
    XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                                promptType:MSIDPromptTypeNever
                                                                                         accountIdentifier:nil
                                                                                    requiresHomeAccountId:NO]);
}

- (void)testShouldAttemptSilent_allInteractivePrompts_returnNo
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                            homeAccountId:@"uid.utid"];
    NSArray<NSNumber *> *interactivePrompts = @[@(MSIDPromptTypeLogin),
                                                @(MSIDPromptTypeConsent),
                                                @(MSIDPromptTypeCreate),
                                                @(MSIDPromptTypeSelectAccount),
                                                @(MSIDPromptTypeRefreshSession)];

    for (NSNumber *prompt in interactivePrompts)
    {
        XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                                    promptType:prompt.integerValue
                                                                                             accountIdentifier:account
                                                                                        requiresHomeAccountId:NO]);
    }
}

- (void)testShouldAttemptSilent_silentPrompts_preserveCallerAccountRequirement
{
    MSIDAccountIdentifier *displayableIdOnlyAccount =
    [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                           homeAccountId:nil];
    NSArray<NSNumber *> *silentPrompts = @[@(MSIDPromptTypePromptIfNecessary),
                                           @(MSIDPromptTypeNever)];

    for (NSNumber *prompt in silentPrompts)
    {
        XCTAssertTrue([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                                   promptType:prompt.integerValue
                                                                                            accountIdentifier:displayableIdOnlyAccount
                                                                                       requiresHomeAccountId:NO]);
        XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptSilentWithForceInteractive:NO
                                                                                                    promptType:prompt.integerValue
                                                                                             accountIdentifier:displayableIdOnlyAccount
                                                                                        requiresHomeAccountId:YES]);
    }
}

- (void)testShouldAttemptInteractive_requiresUIAndNonNeverPrompt
{
    XCTAssertTrue([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptInteractiveWithCanShowUI:YES
                                                                                            promptType:MSIDPromptTypeLogin]);
    XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptInteractiveWithCanShowUI:NO
                                                                                             promptType:MSIDPromptTypeLogin]);
    XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptInteractiveWithCanShowUI:YES
                                                                                             promptType:MSIDPromptTypeNever]);
}

- (void)testShouldAttemptInteractive_allInteractivePrompts_requireUI
{
    NSArray<NSNumber *> *interactivePrompts = @[@(MSIDPromptTypePromptIfNecessary),
                                                @(MSIDPromptTypeLogin),
                                                @(MSIDPromptTypeConsent),
                                                @(MSIDPromptTypeCreate),
                                                @(MSIDPromptTypeSelectAccount),
                                                @(MSIDPromptTypeRefreshSession)];

    for (NSNumber *prompt in interactivePrompts)
    {
        XCTAssertTrue([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptInteractiveWithCanShowUI:YES
                                                                                                promptType:prompt.integerValue]);
        XCTAssertFalse([MSIDBrowserNativeMessageGetTokenRoutingPolicy shouldAttemptInteractiveWithCanShowUI:NO
                                                                                                 promptType:prompt.integerValue]);
    }
}

@end
