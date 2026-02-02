// MySampleEnum.m

#import "MSIDExecutionFlowTag.h"

NSString *MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowNetworkTag state)
{
    switch (state)
    {
        case MSIDExecutionFlowPrepareNetworkRequestTag:
            return @"iq24n";
        case MSIDExecutionFlowCacheResponseFailedObjectTag:
            return @"twoty";
        case MSIDExecutionFlowCacheResponseSucceededObjectTag:
            return @"n3416";
        case MSIDExecutionFlowReceiveNetworkResponseTag:
            return @"UNTAGGED";
        case MSIDExecutionFlowRetryOnNetworkFailureTag:
            return @"rz95n";
        case MSIDExecutionFlowParseNetworkResponseTag:
            return @"fxjo7";
        case MSIDExecutionFlowOtherHttpNetworkStatusCodeTag:
            return @"rz95n";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDExecutionFlowNetworkTag(%ld)", (long)state];
}

NSString *MSIDTokenRequestTagToString(MSIDTokenRequestTag state)
{
    switch (state)
    {
        case MSIDTokenRequestAtExpirationElapsedTag:
            return @"riwx7";
    }

    // Fallback for any future enum values
    return [NSString stringWithFormat:@"MSIDTokenRequestTag(%ld)", (long)state];
}
