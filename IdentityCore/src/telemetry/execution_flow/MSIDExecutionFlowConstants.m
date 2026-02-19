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

#import "MSIDExecutionFlowConstants.h"

NSString *const MSID_EXECUTION_FLOW_TAG  = @"t";

NSString *const MSID_EXECUTION_FLOW_TIME_SPENT  = @"ts";

NSString *const MSID_EXECUTION_FLOW_THREAD_ID  = @"tid";

NSString *const MSID_EXECUTION_FLOW_DIAGNOSTIC_ID  = @"d";

NSString *const MSID_EXECUTION_FLOW_ERROR_CODE  = @"e";

// Log messages
NSString *const MSID_EXECUTION_FLOW_TAG_NIL_MESSAGE = @"Tag cannot be nil";
NSString *const MSID_EXECUTION_FLOW_TID_NIL_MESSAGE = @"tid cannot be nil";
NSString *const MSID_EXECUTION_FLOW_TRIGGERING_TIME_NIL_MESSAGE = @"triggeringTime cannot be nil";
NSString *const MSID_EXECUTION_FLOW_FAILED_TO_CREATE_BLOB_MESSAGE = @"Failed to create execution flow blob";

// JSON formatting constants
NSString *const MSID_EXECUTION_FLOW_JSON_OPEN_BRACKET = @"[";
NSString *const MSID_EXECUTION_FLOW_JSON_COMMA = @",";
NSString *const MSID_EXECUTION_FLOW_JSON_CLOSE_BRACKET = @"]";
NSString *const MSID_EXECUTION_FLOW_JSON_EMPTY_ARRAY = @"[]";

NSString *MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowNetworkTag state)
{
    switch (state)
    {
        case MSIDPrepareNetworkRequestTag:
            return @"iq24n";
        case MSIDCacheResponseFailedObjectTag:
            return @"twoty";
        case MSIDCacheResponseSucceededObjectTag:
            return @"n3416";
        case MSIDReceiveNetworkResponseTag:
            return @"xfx8w";
        case MSIDRetryOnNetworkFailureTag:
            return @"rz95n";
        case MSIDStartToRetryOnNetworkFailureTag:
            return @"6f7qc";
        case MSIDParseNetworkResponseTag:
            return @"fxjo7";
        case MSIDOtherHttpNetworkStatusCodeTag:
            return @"5kbvm";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDExecutionFlowNetworkTag(%ld)", (long)state];
}

NSString *MSIDTokenRequestTagToString(MSIDTokenRequestTag state)
{
    switch (state)
    {
        case MSIDAtExpirationElapsedTag:
            return @"xilux";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDTokenRequestTag(%ld)", (long)state];
}

NSString *MSIDRequestControllerFactoryTagToString(MSIDRequestControllerFactoryTag state)
{
    switch (state)
    {
        case MSIDSilentControllerForParametersTag:
            return @"9jwnp";
        case MSIDSilentControllerShouldUseBrokerTag:
            return @"fi9bq";
        case MSIDSilentControllerCanPerformSsoExtTag:
            return @"e1r45";
        case MSIDSilentControllerCanPerformBrokerXpcTag:
            return @"ahpij";
        case MSIDSilentControllerNoBrokerFallbackTag:
            return @"e3qe8";
        case MSIDSilentControllerFinishTag:
            return @"0vik0";
        case MSIDInteractiveControllerForParametersTag:
            return @"go2o4";
        case MSIDInteractiveControllerShouldUseBrokerTag:
            return @"wj1z1";
        case MSIDInteractiveControllerCanPerformSsoExtTag:
            return @"vfl3d";
        case MSIDInteractiveControllerCanPerformBrokerXpcTag:
            return @"wyxmu";
        case MSIDInteractiveControllerNoBrokerFallbackTag:
            return @"beb43";
        case MSIDInteractiveControllerFinishTag:
            return @"29h5q";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDRequestControllerFactoryTag(%ld)", (long)state];
}
NSString *MSIDSSORemoteInteractiveTokenRequestTagToString(MSIDSSORemoteInteractiveTokenRequestTag state)
{
    switch (state)
    {
        case MSIDInteractiveResolveAuthorityTag:
            return @"ea0zm";
        case MSIDInteractiveHandleOperationResponseTag:
            return @"7iqlk";
        case MSIDInteractiveCompletionTag:
            return @"vy42f";
        case MSIDLegacyBrokerInteractiveCompletionTag:
            return @"UNTAGGED";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDSSORemoteInteractiveTokenRequestTag(%ld)", (long)state];
}

NSString *MSIDSSORemoteSilentTokenRequestTagToString(MSIDSSORemoteSilentTokenRequestTag state)
{
    switch (state)
    {
        case MSIDSilentResolveAuthorityTag:
            return @"n3rpu";
        case MSIDSilentHandleOperationResponseTag:
            return @"u46x0";
        case MSIDSilentCompletionTag:
            return @"x8cgg";
    }
    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDSSORemoteSilentTokenRequestTag(%ld)", (long)state];
}

