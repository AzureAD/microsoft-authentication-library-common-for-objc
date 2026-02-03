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


NSString *MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowNetworkTag state)
{
    switch (state)
    {
        case MSIDExecutionFlowPrepareNetworkRequestTag:
            return @"UNTAGGED";
        case MSIDExecutionFlowCacheResponseFailedObjectTag:
            return @"twoty";
        case MSIDExecutionFlowCacheResponseSucceededObjectTag:
            return @"n3416";
        case MSIDExecutionFlowReceiveNetworkResponseTag:
            return @"xfx8w";
        case MSIDExecutionFlowRetryOnNetworkFailureTag:
            return @"rz95n";
        case MSIDExecutionFlowParseNetworkResponseTag:
            return @"fxjo7";
        case MSIDExecutionFlowOtherHttpNetworkStatusCodeTag:
            return @"5kbvm";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDExecutionFlowNetworkTag(%ld)", (long)state];
}

NSString *MSIDTokenRequestTagToString(MSIDTokenRequestTag state)
{
    switch (state)
    {
        case MSIDTokenRequestAtExpirationElapsedTag:
            return @"5kbvm";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDTokenRequestTag(%ld)", (long)state];
}
