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

#import <XCTest/XCTest.h>
#import "MSIDPKeyAuthHandler.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDRegistrationInformation.h"
#import "NSData+MSIDTestUtil.h"
#import <Security/Security.h>
#import "MSIDPkeyAuthHelper.h"

@interface MSIDPKeyAuthHandlerTests : XCTestCase

@end

@implementation MSIDPKeyAuthHandlerTests

- (void)setUp
{
}

- (void)tearDown
{
}

#pragma mark - Tests

- (void)testParseAuthHeader_whenHeaderIsValidCertAuthorityAsFirstPair_shouldParseIt
{
    __auto_type header = @"PKeyAuth CertAuthorities=\"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net\", Version=\"1.0\", Context=\"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA\", nonce=\"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q\"";
    
    NSDictionary *result = [MSIDPKeyAuthHandler parseAuthHeader:header];
    
    XCTAssertEqual(4, result.count);
    __auto_type context = @"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA";
    XCTAssertEqualObjects(context, result[@"Context"]);
    XCTAssertEqualObjects(@"1.0", result[@"Version"]);
    XCTAssertEqualObjects(@"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q", result[@"nonce"]);
    XCTAssertEqualObjects(@"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net", result[@"CertAuthorities"]);
}

- (void)testParseAuthHeader_whenHeaderIsValidContextAsFirstPair_shouldParseIt
{
    __auto_type header = @"PKeyAuth Context=\"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA\", nonce=\"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q\", CertAuthorities=\"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net\", Version=\"1.0\"";
    
    NSDictionary *result = [MSIDPKeyAuthHandler parseAuthHeader:header];
    
    XCTAssertEqual(4, result.count);
    __auto_type context = @"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA";
    XCTAssertEqualObjects(context, result[@"Context"]);
    XCTAssertEqualObjects(@"1.0", result[@"Version"]);
    XCTAssertEqualObjects(@"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q", result[@"nonce"]);
    XCTAssertEqualObjects(@"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net", result[@"CertAuthorities"]);
}

- (void)testParseAuthHeader_whenHeaderIsValidVersionAsFirstPair_shouldParseIt
{
    __auto_type header = @"PKeyAuth Version=\"1.0\", Context=\"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA\", nonce=\"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q\", CertAuthorities=\"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net\"";
    
    NSDictionary *result = [MSIDPKeyAuthHandler parseAuthHeader:header];
    
    XCTAssertEqual(4, result.count);
    __auto_type context = @"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA";
    XCTAssertEqualObjects(context, result[@"Context"]);
    XCTAssertEqualObjects(@"1.0", result[@"Version"]);
    XCTAssertEqualObjects(@"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q", result[@"nonce"]);
    XCTAssertEqualObjects(@"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net", result[@"CertAuthorities"]);
}

- (void)testParseAuthHeader_whenHeaderIsValidNonceAsFirstPair_shouldParseIt
{
    __auto_type header = @"PKeyAuth nonce=\"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q\", Version=\"1.0\", Context=\"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA\", CertAuthorities=\"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net\"";
    
    NSDictionary *result = [MSIDPKeyAuthHandler parseAuthHeader:header];
    
    XCTAssertEqual(4, result.count);
    __auto_type context = @"rQIIAeNiNdAz1jPQYjbSM7BSSTE2Mks2TE7VNUtONtM1SUk10k1KTUrWNTG1NEw1TTU0Tk0zKBLiEnCUzHp0xzTDfc-RXfUL_0ytf8HIeIGJ8RYTt79jaUmGUUh-dmreKmbpjJKSgmIrff30osSCDL3czOSi_OL8tBK95PzcTcwqaWYmpokplka6qcYWKUDLDBN1k0wNDXRTDJMMLBPNTRItkhNPMTvhMURfLyU1LbE0p0QhvyA1LzNFoaAoPy0zJ1UhPy0tJzMvNT4xOTm1uPgSMxtE_hIzO1TFJWY-VDUXWFhesYhxMAgwSzAoMGgIGDBZcXDwCDCCeItYgV7euWfRAbOIRr_1OyOvhHYlMExgk5nAxjGBjW0Cm_ApNg7fYEcfvUz_4A9sjB3sDDO4GAE1.AQABAAEAAACEfexXxjamQb3OeGQ4GugvpwcjezysrCkHyCNXQL9Q1mZow0TpV_rz1cJST46YOgUfXDRkOX81ocxmgS3OJOXR4gynLAlNWIwRvFUX2MfsLVM8nkI7_iAIqit-KaAnU1Uw428CvPn-f_5UaAJKzA-KwaQyUJz7PkpeE1OKkT0npFi1N3PxJSC_KqaeH7TQjaFs-bN-ZLytcFKrxuSNb55wyN_35OVybKDDqwnxfssAqkty7FPm-r-R_r-vFGsuG7s-HnQiPkGfFkfb8SSEKCsCXj8yMIrrXwriXD4V2UJNDNunQqCz1t14BKf-isNXb2qBSc2vs6zLrwK8aOGcmKMQTxx9sctWEQClAug9ycJEpzyxHhXyiG0HUS0SZoJSF_cx4-pUpqqdiWdpyYEYvU-oRB1tsxQo1yvi8bsCj0XEpcxXWjM9nUXun_KK2feNHuQYDkPWSFApzmTcvUWNux1VWnctbmeITCMhc8bsCOUJ-pQHFxKOgS-TZCoupsd95M__E_nG0GrKQNNccOOyR6LLIAA";
    XCTAssertEqualObjects(context, result[@"Context"]);
    XCTAssertEqualObjects(@"1.0", result[@"Version"]);
    XCTAssertEqualObjects(@"XNme6ZlnnZgIS4bMHPzY4RihkHFqCH6s1hnRgjv8Y0Q", result[@"nonce"]);
    XCTAssertEqualObjects(@"OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97,CN=MS-Organization-Access,DC=windows,DC=net", result[@"CertAuthorities"]);
}

- (void)testParseAuthHeader_whenHeaderInValid_shouldReturnNil
{
    __auto_type header = @"PKeyAuth qweqwe";
    
    NSDictionary *result = [MSIDPKeyAuthHandler parseAuthHeader:header];
    
    XCTAssertNil(result);
}

@end
