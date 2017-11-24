//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDLogger.h"
#import "MSIDRequestContext.h"

#define MSID_LOG(_LVL, _CORRELATION, _CTX, _PII, _FMT, ...) [[MSIDLogger sharedLogger] logLevel:_LVL context:_CTX correlationId:_CORRELATION isPII:_PII format:_FMT, ##__VA_ARGS__]

#define MSID_LOG_ERROR(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelError, _correlationId, _ctx, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_ERROR_PII(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelError, _correlationId, _ctx, YES, _fmt, ##__VA_ARGS__)

#define MSID_LOG_WARN(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelWarning, _correlationId, _ctx, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_WARN_PII(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelWarning, _correlationId, _ctx, YES, _fmt, ##__VA_ARGS__)

#define MSID_LOG_INFO(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelInfo, _correlationId, _ctx, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_INFO_PII(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelInfo, _correlationId, _ctx, YES, _fmt, ##__VA_ARGS__)

#define MSID_LOG_VERBOSE(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelVerbose, _correlationId, _ctx, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_VERBOSE_PII(_correlationId, _ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelVerbose, _correlationId, _ctx, YES, _fmt, ##__VA_ARGS__)

@interface MSIDLogger (Internal)

/*!
 Logs message with the specified level. If correlationId is nil, uses correlationId from the context.
 @param context         Log context, provides correlationId and log component
 @param correlationId   Alternative way to pass correlationId for cases when context is not available
 @param isPii           Specifies if message contains PII
 @param format          Message format
 */

- (void)logLevel:(MSIDLogLevel)level
         context:(id<MSIDRequestContext>)context
   correlationId:(NSUUID *)correlationId
           isPII:(BOOL)isPii
          format:(NSString *)format, ... NS_FORMAT_FUNCTION(5, 6);

- (void)logToken:(NSString *)token
       tokenType:(NSString *)tokenType
   expiresOnDate:(NSDate *)expiresOn
    additionaLog:(NSString *)additionalLog
         context:(id<MSIDRequestContext>)context;

@end
