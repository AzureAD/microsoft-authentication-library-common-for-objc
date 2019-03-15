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

#import "NSOrderedSet+MSIDExtensions.h"
#import "NSString+MSIDTelemetryExtensions.h"
#import "NSDictionary+MSIDExtensions.h"
#import "NSMutableDictionary+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "NSURL+MSIDExtensions.h"
#import "NSDate+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"
#import "NSData+JWT.h"
#import "NSError+MSIDExtensions.h"
#import "MSIDLogger+Internal.h"
#import "MSIDError.h"
#import "MSIDOAuth2Constants.h"

// Utility macros for convience classes wrapped around dictionaries
#define DICTIONARY_READ_PROPERTY_IMPL(DICT, KEY, GETTER) \
- (NSString *)GETTER \
{ \
    if ([[DICT objectForKey:KEY] isKindOfClass:[NSString class]]) \
    { \
        return [DICT objectForKey:KEY]; \
    } \
    return nil; \
}

#define DICTIONARY_WRITE_PROPERTY_IMPL(DICT, KEY, SETTER) \
- (void)SETTER:(NSString *)value { [DICT setValue:[value copy] forKey:KEY]; }

#define STRING_CASE(_CASE) case _CASE: return @#_CASE

/**
 * @discussion Workaround for exporting symbols from category object files. See article
 * https://medium.com/ios-os-x-development/categories-in-static-libraries-78e41f8ddb96#.aedfl1kl0
 */
__attribute__((used)) static void importCategories() {
  [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@ %@ %@ %@ %@", NSOrderedSetMSIDExtensionsCategory, NSStringMSIDTelemetryExtensionsCategory, NSDictionaryMSIDExtensionsCategory, NSMutableDictionaryMSIDExtensionsCategory, NSStringMSIDExtensionsCategory, NSURLMSIDExtensionsCategory, NSDateMSIDExtensionsCategory, NSDataMSIDExtensionsCategory, NSDataJWTCategory, NSErrorMSIDExtensionsCategory];
}
