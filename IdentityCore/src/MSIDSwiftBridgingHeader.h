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

/*
 For Swift files added in common-core, if the classes are annotated with @objc, the classes are available to use
 by other objective-c classes in the same target. Xcode generates a bridging header to achieve this with the name <ModuleName>-Swift.h
 Xcode automatically builds this bridging header in derived data when building the target.
 
 When common-core is used as a subtree in MSAL/oneAuth, the bridging header is created in IdentityCore's targets for swift files in common-core by Xcode.
 Obj C classes that want to use these swift classes must import the bridging header.
 But when common-core is a subfolder in MSAL/oneAuth Pod using Cocoapods,
 during pod creation, the bridging header is created in MSAL/oneAuth's target instead of common-core's target.
 
 This header file serves as a common place to import the correct bridging header based on whether common-core is used as a subtree
 in MSAL/oneAuth during Pod creation.
 
 MSAL podspec defines MSAL_COCOAPOD macro during pod creation and oneAuth defines ONEAUTH_COCOAPOD macro in its podspec.
 */

#if defined(MSAL_COCOAPOD)
#import "MSAL/MSAL-Swift.h"
#elif defined(ONEAUTH_COCOAPOD)
#import "OneAuth-Swift.h"
#else
#import "IdentityCore-Swift.h"
#endif
