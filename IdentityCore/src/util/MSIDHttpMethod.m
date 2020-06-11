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

#import "MSIDHttpMethod.h"

NSString * MSIDHttpMethodFromType(MSIDHttpMethod type)
{
    switch (type) {
        case MSIDHttpMethodGET:
            return @"GET";
        case MSIDHttpMethodHEAD:
            return @"HEAD";
        case MSIDHttpMethodPOST:
            return @"POST";
        case MSIDHttpMethodPUT:
            return @"PUT";
        case MSIDHttpMethodDELETE:
            return @"DELETE";
        case MSIDHttpMethodCONNECT:
            return @"CONNECT";
        case MSIDHttpMethodOPTIONS:
            return @"OPTIONS";
        case MSIDHttpMethodTRACE:
            return @"TRACE";
        case MSIDHttpMethodPATCH:
            return @"PATCH";
        default:
            return @"GET";
    }
}

MSIDHttpMethod MSIDHttpMethodFromString(NSString *httpMethodString)
{
    if ([httpMethodString isEqualToString:@"GET"])
    {
        return MSIDHttpMethodGET;
    }
    else if ([httpMethodString isEqualToString:@"HEAD"])
    {
        return MSIDHttpMethodHEAD;
    }
    else if ([httpMethodString isEqualToString:@"POST"])
    {
        return MSIDHttpMethodPOST;
    }
    else if ([httpMethodString isEqualToString:@"PUT"])
    {
        return MSIDHttpMethodPUT;
    }
    else if ([httpMethodString isEqualToString:@"DELETE"])
    {
        return MSIDHttpMethodDELETE;
    }
    else if ([httpMethodString isEqualToString:@"CONNECT"])
    {
        return MSIDHttpMethodCONNECT;
    }
    else if ([httpMethodString isEqualToString:@"OPTIONS"])
    {
        return MSIDHttpMethodOPTIONS;
    }
    else if ([httpMethodString isEqualToString:@"TRACE"])
    {
        return MSIDHttpMethodTRACE;
    }
    else if ([httpMethodString isEqualToString:@"PATCH"])
    {
        return MSIDHttpMethodPATCH;
    }

    return MSIDHttpMethodGET;
}
