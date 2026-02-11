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

#import <Foundation/Foundation.h>

/**
 Each enum tag must be unique within the codebase. Reuse is allowed only when two flows are mutually exclusive for a single token request (i.e., flow A or flow B can occur, but never both in the same request).
 Although different execution‑flow blobs may share the same tag in the final flow.

 To generate a new tag, follow these steps:
   1. Add a meaningful enum and Insert the corresponding string placeholder "UNTAGGED" in MSIDExecutionFlowConstants.m where you need the new tag.
   2. Commit and push your changes to GitHub.
   3. A GitHub Action will automatically replace every "UNTAGGED" placeholder
      with a unique, valid 5‑character tag and create a follow-up commit.

 This ensures all tags remain distinct while streamlining the tagging process.
 */

// Required
extern NSString * _Nonnull const MSID_EXECUTION_FLOW_TAG;
extern NSString * _Nonnull const MSID_EXECUTION_FLOW_TIME_SPENT;
extern NSString * _Nonnull const MSID_EXECUTION_FLOW_THREAD_ID;

// Optional
extern NSString * _Nonnull const MSID_EXECUTION_FLOW_DIAGNOSTIC_ID;
extern NSString * _Nonnull const MSID_EXECUTION_FLOW_ERROR_CODE;

// Log messages
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_TAG_NIL_MESSAGE;
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_TID_NIL_MESSAGE;
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_TRIGGERING_TIME_NIL_MESSAGE;
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_FAILED_TO_CREATE_BLOB_MESSAGE;

// JSON formatting constants
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_JSON_OPEN_BRACKET;
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_JSON_COMMA;
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_JSON_CLOSE_BRACKET;
FOUNDATION_EXPORT NSString * _Nonnull const MSID_EXECUTION_FLOW_JSON_EMPTY_ARRAY;
/// A enum of MSIDExecutionFlowNetworkT@"e"ag.
typedef NS_ENUM(NSInteger, MSIDExecutionFlowNetworkTag)
{
    MSIDExecutionFlowPrepareNetworkRequestTag = 0,
    MSIDExecutionFlowCacheResponseFailedObjectTag,
    MSIDExecutionFlowCacheResponseSucceededObjectTag,
    MSIDExecutionFlowReceiveNetworkResponseTag,
    MSIDExecutionFlowRetryOnNetworkFailureTag,
    MSIDExecutionFlowStartToRetryOnNetworkFailureTag,
    MSIDExecutionFlowParseNetworkResponseTag,
    MSIDExecutionFlowOtherHttpNetworkStatusCodeTag,
};

/// Returns the string representation for each MSIDExecutionFlowNetworkTag value.
FOUNDATION_EXPORT NSString * _Nonnull MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowNetworkTag state);

/// A enum of MSIDTokenRequestTag.
typedef NS_ENUM(NSInteger, MSIDTokenRequestTag)
{
    MSIDTokenRequestAtExpirationElapsedTag = 0,
};

/// Returns the string representation for each MSIDTokenRequestTag value.
FOUNDATION_EXPORT NSString * _Nonnull MSIDTokenRequestTagToString(MSIDTokenRequestTag state);

/// An enum of MSIDRequestControllerFactoryTag.
typedef NS_ENUM(NSInteger, MSIDRequestControllerFactoryTag)
{
    MSIDRequestControllerFactorySilentControllerForParametersTag = 0,
    MSIDRequestControllerFactorySilentControllerShouldUseBrokerTag,
    MSIDRequestControllerFactorySilentControllerCanPerformSsoExtTag,
    MSIDRequestControllerFactorySilentControllerCanPerformBrokerXpcTag,
    MSIDRequestControllerFactorySilentControllerNoBrokerFallbackTag,
    MSIDRequestControllerFactorySilentControllerFinishTag,
    MSIDRequestControllerFactoryInteractiveControllerForParametersTag,
    MSIDRequestControllerFactoryInteractiveControllerShouldUseBrokerTag,
    MSIDRequestControllerFactoryInteractiveControllerCanPerformSsoExtTag,
    MSIDRequestControllerFactoryInteractiveControllerCanPerformBrokerXpcTag,
    MSIDRequestControllerFactoryInteractiveControllerNoBrokerFallbackTag,
    MSIDRequestControllerFactoryInteractiveControllerFinishTag
};

/// Returns the string representation for each MSIDRequestControllerFactoryTag value.
FOUNDATION_EXPORT NSString * _Nonnull MSIDRequestControllerFactoryTagToString(MSIDRequestControllerFactoryTag state);

/// An enum of MSIDSSORemoteInteractiveTokenRequestTag.
typedef NS_ENUM(NSInteger, MSIDSSORemoteInteractiveTokenRequestTag)
{
    MSIDSSORemoteInteractiveTokenRequestResolveAuthorityTag = 0,
    MSIDSSORemoteInteractiveTokenRequestHandleOperationResponseTag,
    MSIDSSORemoteInteractiveTokenRequestCompletionTag
};

/// Returns the string representation for each MSIDSSORemoteInteractiveTokenRequestTag value.
FOUNDATION_EXPORT NSString * _Nonnull MSIDSSORemoteInteractiveTokenRequestTagToString(MSIDSSORemoteInteractiveTokenRequestTag state);

/// An enum of MSIDSSORemoteSilentTokenRequestTag.
typedef NS_ENUM(NSInteger, MSIDSSORemoteSilentTokenRequestTag)
{
    MSIDSSORemoteSilentTokenRequestResolveAuthorityTag = 0,
    MSIDSSORemoteSilentTokenRequestHandleOperationResponseTag,
    MSIDSSORemoteSilentTokenRequestCompletionTag
};
/// Returns the string representation for each MSIDSSORemoteSilentTokenRequestTag value.
FOUNDATION_EXPORT NSString * _Nonnull MSIDSSORemoteSilentTokenRequestTagToString(MSIDSSORemoteSilentTokenRequestTag state);


