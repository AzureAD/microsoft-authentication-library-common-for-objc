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

#import "MSIDAssymetricKeyPair+Test.h"

@implementation MSIDAssymetricKeyPair (Test)

- (nullable NSString *)encryptForTest:(nonnull NSString *)messageString
{
    NSData * message = [[NSData alloc] initWithBase64EncodedString:messageString options:0];
    
    if ([message length] == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Message to encrypt was empty");
        return nil;
    }

    if (@available(iOS 10.0, macOS 10.12, *))
    {
        SecKeyAlgorithm algorithm = kSecKeyAlgorithmRSAEncryptionOAEPSHA1;
        
        if (!SecKeyIsAlgorithmSupported(_publicKeyRef, kSecKeyOperationTypeEncrypt, algorithm)) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to use the requested crypto algorithm with the provided key.");
            return nil;
        }

        CFErrorRef error = nil;
        NSData *encryptedBlobBytes = (NSData *)CFBridgingRelease(
            SecKeyCreateEncryptedData(_publicKeyRef, algorithm, (__bridge CFDataRef)message, &error));
        if (error)
        {
            NSError *err = CFBridgingRelease(error);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", [@"Unable to encrypt data" stringByAppendingString:[NSString stringWithFormat:@"%ld", (long)err.code]]);
            return nil;
        }
        return [encryptedBlobBytes base64EncodedStringWithOptions:0];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Unable to use the requested crypto algorithm with the provided key.");
        return nil;
    }
}

@end
