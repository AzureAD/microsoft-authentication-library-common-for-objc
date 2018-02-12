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

#import "MSIDAADTokenResponse.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDAADV1IdToken.h"

@interface MSIDAADTokenResponse ()

@property (readonly) NSString *rawClientInfo;

@end

@implementation MSIDAADTokenResponse

// Default properties for an error response
MSID_JSON_ACCESSOR(MSID_OAUTH2_CORRELATION_ID_RESPONSE, correlationId)

// Default properties for a successful response
MSID_JSON_ACCESSOR(MSID_OAUTH2_EXPIRES_ON, expiresOn);
MSID_JSON_ACCESSOR(MSID_OAUTH2_EXT_EXPIRES_IN, extendedExpiresIn)
MSID_JSON_ACCESSOR(MSID_OAUTH2_RESOURCE, resource)
MSID_JSON_ACCESSOR(MSID_OAUTH2_CLIENT_INFO, rawClientInfo)
MSID_JSON_ACCESSOR(MSID_FAMILY_ID, familyId)
MSID_JSON_ACCESSOR(MSID_TELEMETRY_KEY_SPE_INFO, speInfo)

- (id)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    if (self.extendedExpiresIn)
    {
        _extendedExpiresOnDate = [NSDate dateWithTimeIntervalSinceNow:[self.extendedExpiresIn doubleValue]];
    }
    
    if (self.rawClientInfo)
    {
        _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:self.rawClientInfo error:nil];
    }
    
    return self;
}

- (NSDate *)expiryDate
{
    NSDate *date = [super expiryDate];
    
    if (date)
    {
        return date;
    }
    
    NSString *expiresOn = self.expiresOn;
    
    if (!expiresOn)
    {
        if (_json[MSID_OAUTH2_EXPIRES_ON])
        {
            MSID_LOG_WARN(nil, @"Unparsable time - The response value for the access token expiration cannot be parsed: %@", _json[MSID_OAUTH2_EXPIRES_ON]);
        }
        
        return nil;
    }
    
    return [NSDate dateWithTimeIntervalSince1970:[expiresOn integerValue]];
}

@end
