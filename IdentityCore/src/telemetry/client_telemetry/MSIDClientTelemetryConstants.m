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


#import "MSIDClientTelemetryConstants.h"

// Key
NSString* const MSID_TELE_HANDLING_HTTP_ERROR = @"handle_http_error";
NSString* const MSID_TELE_HTTP_ERROR_CODE = @"http_error_code";
NSString* const MSID_TELE_HTTP_SHOULD_RETRY = @"http_should_retry";
NSString* const MSID_TELE_HTTP_RETRY_INTERVAL = @"http_retry_interval";

NSString* const MSID_TELE_ENROLL_ID_MATCH = @"enroll_id_match";
NSString* const MSID_TELE_ACCESS_TOKEN_EXPIRED_INTERVAL = @"at_exipred_interval";
NSString* const MSID_TELE_FOUND_VALID_ACCESS_TOKEN = @"found_valid_at";
NSString* const MSID_TELE_ACCESS_TOKEN_REFRESHED_NEEDED = @"at_refresh_needed";
NSString* const MSID_TELE_SKIP_LOCAL_REFRESH_TOKEN = @"skip_local_rt";

// Value
NSString* const MSID_TELE_NO_HTTP_RESPONSE = @"no_response";
NSString* const MSID_TELE_5XX_ERROR = @"5xx_error";
