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

#import "NSData+JWT.h"
#import <Security/Security.h>
#import <Security/SecKey.h>

@implementation NSData (JWT)

- (NSData *)msidSignHashWithPrivateKey:(SecKeyRef)privateKey
{
    if (!privateKey)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Cannot sign JWT data with a NULL private key.");
        return nil;
    }

    CFErrorRef subError = NULL;
    NSData *signature = (NSData *)CFBridgingRelease(SecKeyCreateSignature(privateKey,
                                                                          kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256,
                                                                          (__bridge CFDataRef)self,
                                                                          &subError));

    if (!signature)
    {
        NSError *signingError = nil;
        if (subError)
        {
            signingError = CFBridgingRelease(subError);
        }

        NSString *errorDescription = @"Failed to sign JWT data with key.";
        if (signingError)
        {
            errorDescription = [NSString stringWithFormat:@"%@ Underlying error: %@", errorDescription, signingError];
        }

        MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, signingError, nil, nil, YES);
    }
    return signature;
}

@end
