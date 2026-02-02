#import <Foundation/Foundation.h>

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
    MSIDExecutionFlowParseNetworkResponseTag,
    MSIDExecutionFlowOtherHttpNetworkStatusCodeTag,
};

/// Returns the string representation for each MSIDExecutionFlowNetworkTag value.
FOUNDATION_EXPORT NSString *MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowNetworkTag state);

/// A enum of MSIDTokenRequestTag.
typedef NS_ENUM(NSInteger, MSIDTokenRequestTag)
{
    MSIDTokenRequestAtExpirationElapsedTag = 0,
};

/// Returns the string representation for each MSIDTokenRequestTag value.
FOUNDATION_EXPORT NSString *MSIDTokenRequestTagToString(MSIDTokenRequestTag state);
