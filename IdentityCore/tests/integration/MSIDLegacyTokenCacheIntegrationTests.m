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

@interface MSIDLegacyTokenCacheTests : XCTestCase

@end

@implementation MSIDLegacyTokenCacheTests

#pragma mark - Saving

- (void)testSaveAccessToken_withWrongParameters_shouldReturnError
{
    
}

- (void)testSaveAccessToken_withTokenAndAccount_shouldSaveToken
{
    
}

- (void)testSaveSharedRTForAccount_withMRRT_shouldSaveOneEntry
{
    
}

- (void)testSaveSharedRTForAccount_withFRT_shouldSaveTwoEntries
{
    
}

#pragma mark - Retrieve

- (void)testGetAccessToken_whenNoItemsInCache_shouldReturnNil
{
    
}

- (void)testGetAccessToken_withWrongParameters_shouldReturnError
{
    
}

- (void)testGetAccessToken_withCorrectAccountAndParameters_shouldReturnToken
{
    
}

- (void)testGetSharedRTForAccount_whenNoItemsInCache_shouldReturnNil
{
    
}

- (void)testGetSharedRTForAccount_whenAccountWithUPNProvided_shouldReturnToken
{
    
}

- (void)testGetSharedRTForAccount_whenAccountWithUidUtidProvided_shouldReturnToken
{
    
}

- (void)testGetSharedRTForAccount_whenLegacyItemsInCache_andAccountWithUidUtidProvided_shouldReturnNil
{
    
}

- (void)testGetAllSharedRTs_whenNoItemsInCache_shouldReturnEmptyResult
{
    
}

- (void)testGetAllSharedRTs_whenItemsInCacheAccountWithUPNProvided_shouldReturnItems
{
    
}

- (void)testGetAllSharedRTs_whenItemsInCacheAccountWithUidUtidProvided_shouldReturnItems
{
    
}

- (void)testGetAllSharedRTs_whenLegacyItemsInCache_andAccountWithUidUtidProvided_shouldReturnItems
{
    
}

- (void)testRemovedSharedRTForAccount_whenNoItemsInCache_shouldReturnYes
{
    
}

#pragma mark - Remove

- (void)testRemoveSharedRTForAccount_whenItemInCache_andAccountWithUPNProvided_shouldRemoveItem
{
    
}

- (void)testRemoveSharedRTForAccount_whenItemInCache_andAccountWithUidUtidProvided_shouldRemoveItem
{
    
}

- (void)testRemoveSharedRTForAccount_whenLegacyItemInCache_andAccountWithUidUtidProvided_shouldNotRemoveItems
{
    
}

@end
