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

extern NSString * _Nonnull const MSID_EXECUTION_FLOW_TAG;

extern NSString * _Nonnull const MSID_EXECUTION_FLOW_TIME_SPENT;

extern NSString * _Nonnull const MSID_EXECUTION_FLOW_THREAD_ID;

/**
 Each enum tag must be unique within the codebase—you cannot reuse the same tag in different locations,
 although different execution‑flow blobs may share a tag in the final flow.

 To assign a tag, simply use the placeholder "UNTAGGED" and run the retagging script from the project root:

     python3 retag_untagged.py

 This script will replace every "UNTAGGED" placeholder with a valid, unique 5‑character tag.
 */

/// A enum of MSIDExecutionFlowNetworkTag.
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
