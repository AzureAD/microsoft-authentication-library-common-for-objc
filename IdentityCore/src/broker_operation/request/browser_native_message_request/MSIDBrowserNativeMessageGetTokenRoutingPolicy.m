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

#import "MSIDBrowserNativeMessageGetTokenRoutingPolicy.h"
#import "MSIDAccountIdentifier.h"

@implementation MSIDBrowserNativeMessageGetTokenRoutingPolicy

+ (MSIDBrowserNativeMessageGetTokenRoute)routeWithForceInteractive:(BOOL)forceInteractive
                                                        promptType:(MSIDPromptType)promptType
                                                         canShowUI:(BOOL)canShowUI
                                                  accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                                             requiresHomeAccountId:(BOOL)requiresHomeAccountId
{
    BOOL shouldAttemptSilent =
    [self shouldAttemptSilentWithForceInteractive:forceInteractive
                                       promptType:promptType
                                accountIdentifier:accountIdentifier
                           requiresHomeAccountId:requiresHomeAccountId];
    if (shouldAttemptSilent)
    {
        return MSIDBrowserNativeMessageGetTokenRouteSilent;
    }

    if (promptType == MSIDPromptTypeNever)
    {
        return MSIDBrowserNativeMessageGetTokenRouteInteractionRequired;
    }

    if (!canShowUI)
    {
        return MSIDBrowserNativeMessageGetTokenRouteUIBlocked;
    }

    return MSIDBrowserNativeMessageGetTokenRouteInteractive;
}

+ (BOOL)shouldAttemptSilentWithForceInteractive:(BOOL)forceInteractive
                                      promptType:(MSIDPromptType)promptType
                               accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                          requiresHomeAccountId:(BOOL)requiresHomeAccountId
{
    // A caller sets forceInteractive after silent acquisition requires interaction or when local
    // prerequisites, such as a PRT, are unavailable. Retrying silently would repeat the same failure.
    if (forceInteractive)
    {
        return NO;
    }

    // Browser-native GetToken supports silent acquisition only for an omitted prompt or prompt=none.
    // All other supported prompt values explicitly require user interaction.
    if (promptType != MSIDPromptTypeNever
        && promptType != MSIDPromptTypePromptIfNecessary)
    {
        return NO;
    }

    if (!accountIdentifier)
    {
        return NO;
    }

    // Broker-local non-STS requests require a stable home account ID. STS and in-process BART
    // callers can resolve an account from a displayable ID, so they pass NO for this requirement.
    if (!requiresHomeAccountId)
    {
        return YES;
    }

    return accountIdentifier.homeAccountId != nil;
}

+ (BOOL)shouldAttemptInteractiveWithCanShowUI:(BOOL)canShowUI
                                    promptType:(MSIDPromptType)promptType
{
    // prompt=none is a protocol guarantee that UI will not be shown, regardless of caller capability.
    return canShowUI && promptType != MSIDPromptTypeNever;
}

@end
