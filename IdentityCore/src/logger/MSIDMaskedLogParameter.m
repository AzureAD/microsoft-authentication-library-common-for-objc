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

#import "MSIDMaskedLogParameter.h"

@interface MSIDMaskedLogParameter()

@property (nonatomic, readwrite) id parameterValue;
@property (nonatomic, readwrite) NSString *maskedParameterValue;
@property (nonatomic, readwrite) NSString *euiiMaskedParameterValue;
@property (nonatomic, readwrite) BOOL isEUII;

@end

@implementation MSIDMaskedLogParameter

#pragma mark - Init

- (instancetype)initWithParameterValue:(id)parameter
{
    return [self initWithParameterValue:parameter isEUII:NO];
}

- (instancetype)initWithParameterValue:(id)parameter isEUII:(BOOL)isEUII
{
    self = [super init];
    
    if (self)
    {
        _parameterValue = parameter;
        _isEUII = isEUII;
    }
    
    return self;
}

#pragma mark - Description

- (NSString *)description
{
    switch ([MSIDLogger sharedLogger].logMaskingLevel)
    {
        case MSIDLogMaskingSettingsMaskAllPII:
        {
            if (self.maskedParameterValue) return self.maskedParameterValue;
            
            self.maskedParameterValue = [self maskedDescription];
            return self.maskedParameterValue;
        }
        case MSIDLogMaskingSettingsMaskEUIIOnly:
        {
            if (self.euiiMaskedParameterValue) return self.euiiMaskedParameterValue;
            
            self.euiiMaskedParameterValue = [self EUIIMaskedDescription];
            return self.euiiMaskedParameterValue;
        }
        default:
        {
            return [self noMaskWithCondition]; // no masking with condition
        }
    }
}
 
#pragma mark - Masking

- (NSString *)maskedDescription
{
    // Provide custom handling for some common data types
    if ([self.parameterValue isKindOfClass:[NSArray class]])
    {
        NSArray *arrayParameter = (NSArray *)self.parameterValue;
        return [NSString stringWithFormat:@"MaskedArray(count=%ld)", (long)arrayParameter.count];
    }
    else if ([self.parameterValue isKindOfClass:[NSError class]])
    {
        NSError *errorParameter = (NSError *)self.parameterValue;
        return [NSString stringWithFormat:@"MaskedError(%@, %ld)", errorParameter.domain, (long)errorParameter.code];
    }
    
    return [NSString stringWithFormat:@"Masked%@", _PII_NULLIFY(self.parameterValue)];
}

- (NSString *)EUIIMaskedDescription
{
    if (self.isEUII)
    {
        return [self maskedDescription];
    }
    
    return [self noMaskWithCondition];
}

- (NSString *)noMaskWithCondition
{
    // If input is NSError, mask userinfo as it may contain upn
    if ([self.parameterValue isKindOfClass:[NSError class]])
    {
        NSError *errorParameter = (NSError *)self.parameterValue;
        if (errorParameter.userInfo && errorParameter.userInfo.allKeys.count > 0)
        {
            NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}";
            NSPredicate *emailPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
            BOOL maskedError = NO;
            NSMutableDictionary *localUserInfo = [errorParameter.userInfo mutableCopy];
            for (NSErrorUserInfoKey key in errorParameter.userInfo)
            {
                if ([errorParameter.userInfo[key] isKindOfClass:NSString.class])
                {
                    if ([emailPredicate evaluateWithObject:errorParameter.userInfo[key]])
                    {
                        localUserInfo[key] = _PII_NULLIFY(errorParameter.userInfo[key]);
                        maskedError = YES;
                    }
                }
            }
            if (maskedError)
            {
                return [NSString stringWithFormat:@"MaskedError(%@, %ld, %@)", errorParameter.domain, (long)errorParameter.code, localUserInfo];
            }
        }
    }
    
    return [NSString stringWithFormat:@"%@", self.parameterValue]; // For a generic case, don't mask it
}

@end
