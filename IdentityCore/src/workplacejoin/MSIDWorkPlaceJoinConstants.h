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

#import <Foundation/Foundation.h>

#pragma once

extern NSString *const kMSIDDefaultSharedGroup;
extern NSString *const kMSIDPrivateKeyIdentifier;
extern NSString *const kMSIDPublicKeyIdentifier;
extern NSString *const kMSIDUpnIdentifier;
extern NSString *const kMSIDApplicationIdentifierPrefix;
extern NSString *const kMSIDOauthRedirectUri;
extern NSString *const kMSIDProtectionSpaceDistinguishedName;

#pragma mark Error strings
extern NSString *const kMSIDErrorDomain;
extern NSString *const kMSIDAlreadyWorkplaceJoined;
extern NSString *const kMSIDInvalidUPN;
extern NSString *const kMSIDUnabletoWriteToSharedKeychain;
extern NSString *const kMSIDUnabletoReadFromSharedKeychain;
extern NSString *const kMSIDDuplicateCertificateEntry;
extern NSString *const kMSIDCertificateInstallFailure;
extern NSString *const kMSIDCertificateDeleteFailure;
extern NSString *const kMSIDUpnMismatchOnJoin;
extern NSString *const kMSIDWwwAuthenticateHeader;
extern NSString *const kMSIDPKeyAuthUrn;
extern NSString *const kMSIDPKeyAuthHeader;
extern NSString *const kMSIDPKeyAuthHeaderVersion;
extern NSString *const kMSIDPKeyAuthName;

typedef enum errorCodeTypes
{
    msidFailure                                     = -500,      //Failure when trying to perform authenticate and get token via MSID
    sharedKeychainPermission                        = -400,      //Failure when modifying shared app keycahin applicaiton deployed without access.
    networkFailures                                 = -300,      //Failures as a result of an NSURLConnection generally a retry should resolve these failures
    drsFailures                                     = -200,      //DRS call returns an error message or poor JSON - may want to communicate message to user
    apiFailure                                      = -100       //Device previously workplace joined or invalid UPN
} ErrorCodes;


//MSID

#pragma mark general
extern NSString *const kMSIDOID;
static NSInteger kMSIDDeviceIDLength = 38;

#pragma Base64Decoding

// Base64 quantum size (in bytes)
// Note that a quantum is the smallest unit in base64-encoding/decoding.
static NSInteger kMSIDBASE64QUANTUM = 3;

// Each quantum takes 4 characters to represent.
static NSInteger kMSIDBASE64QUANTUMREP = 4;

//
// Mapping from ASCII character to 6 bit pattern.
//
static unsigned char kMSIDDecodeBase64[256] = {
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x00
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x10
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x20
    64, 64, 64, 62, 64, 64, 64, 63,
    52, 53, 54, 55, 56, 57, 58, 59,  // 0x30
    60, 61, 64, 64, 64,  0, 64, 64,
    64,  0,  1,  2,  3,  4,  5,  6,  // 0x40
    7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22,  // 0x50
    23, 24, 25, 64, 64, 64, 64, 64,
    64, 26, 27, 28, 29, 30, 31, 32,  // 0x60
    33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48,  // 0x70
    49, 50, 51, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x80
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x90
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xA0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xB0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xC0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xD0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xE0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xF0
    64, 64, 64, 64, 64, 64, 64, 64,
};

