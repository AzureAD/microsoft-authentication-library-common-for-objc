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

#import "MSIDAADResponseSerializer.h"
#import "MSIDTelemetryEventStrings.h"
#import "NSString+MSIDTelemetryExtensions.h"

@implementation MSIDAADResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError **)error
{
    NSMutableDictionary *jsonObject = [[super responseObjectForResponse:response data:data error:error] mutableCopy];
    
    if (error) return nil;
    
    if ([response isKindOfClass:NSHTTPURLResponse.class])
    {
        __auto_type httpResponse = (NSHTTPURLResponse *)response;
        
        jsonObject[MSID_OAUTH2_CORRELATION_ID_RESPONSE] = httpResponse.allHeaderFields[MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE];

        NSString *clientTelemetry = httpResponse.allHeaderFields[MSID_OAUTH2_CLIENT_TELEMETRY];
        if (![NSString msidIsStringNilOrBlank:clientTelemetry])
        {
            NSString *speInfo = [clientTelemetry parsedClientTelemetry][MSID_TELEMETRY_KEY_SPE_INFO];

            if (![NSString msidIsStringNilOrBlank:speInfo])
            {
                jsonObject[MSID_TELEMETRY_KEY_SPE_INFO] = speInfo;
            }
        }
    }

    return jsonObject;
}

@end
