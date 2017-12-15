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

#import "MSIDMSIDJsonSerializer.h"
#import "MSIDToken.h"

@implementation MSIDMSIDJsonSerializer

- (NSData *)serialize:(MSIDToken *)token
{
    NSError *error;
    NSData *data = [token serialize:&error];
    
    if (error)
    {
        return nil;
        MSID_LOG_ERROR(nil, @"Failed to serialize token.");
        MSID_LOG_ERROR_PII(nil, @"Failed to serialize token, error: %@", error);
    }

    
    return data;
}

- (MSIDToken *)deserialize:(NSData *)data
{
    NSError *error;
    MSIDToken *token = [[MSIDToken alloc] initWithJSONData:data error:&error];
    
    if (error)
    {
        return nil;
        MSID_LOG_ERROR(nil, @"Failed to deserialize json object.");
        MSID_LOG_ERROR_PII(nil, @"Failed to deserialize json object, error: %@", error);
    }
    
    return token;
}

@end
