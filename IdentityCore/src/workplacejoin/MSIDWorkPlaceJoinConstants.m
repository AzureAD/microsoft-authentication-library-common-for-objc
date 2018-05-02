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

#import "MSIDWorkPlaceJoinConstants.h"

NSString *const kMSIDDefaultSharedGroup                = @"com.microsoft.workplacejoin";
NSString *const kMSIDPrivateKeyIdentifier               = @"com.microsoft.workplacejoin.privatekey\0";
NSString *const kMSIDPublicKeyIdentifier                = @"com.microsoft.workplacejoin.publickey\0";
NSString *const kMSIDUpnIdentifier                      = @"com.microsoft.workplacejoin.registeredUserPrincipalName";
NSString *const kMSIDApplicationIdentifierPrefix        = @"applicationIdentifierPrefix";
NSString *const kMSIDOauthRedirectUri                  = @"ms-app://windows.immersivecontrolpanel";
NSString *const kMSIDProtectionSpaceDistinguishedName   = @"MS-Organization-Access";
//
//#pragma mark Error strings
NSString *const kMSIDErrorDomain                        = @"com.microsoft.workplacejoin.errordomain";
NSString *const kMSIDAlreadyWorkplaceJoined             = @"This device is already workplace joined";
NSString *const kMSIDInvalidUPN                         = @"Invalid UPN";
NSString *const kMSIDUnabletoWriteToSharedKeychain      = @"Unable to write to shared access group: %@";
NSString *const kMSIDUnabletoReadFromSharedKeychain     = @"Unable to read from shared access group: %@ with error code: %@";
NSString *const kMSIDDuplicateCertificateEntry          = @"Duplicate workplace certificate entry";
NSString *const kMSIDCertificateInstallFailure          = @"Install workplace certificate failure";
NSString *const kMSIDCertificateDeleteFailure           = @"Delete workplace certificate failure";
NSString *const kMSIDUpnMismatchOnJoin                  = @"Original upn: %@ does not match the one we recieved from DRS: %@";
NSString *const kMSIDWwwAuthenticateHeader              = @"WWW-Authenticate";
NSString *const kMSIDPKeyAuthUrn                        = @"urn:http-auth:PKeyAuth?";
NSString *const kMSIDPKeyAuthHeader                     = @"x-ms-PkeyAuth";
NSString *const kMSIDPKeyAuthHeaderVersion              = @"1.0";
NSString *const kMSIDPKeyAuthName                       = @"PKeyAuth";

#pragma mark general
NSString *const kMSIDOID                                = @"1.2.840.113556.1.5.284.2";



