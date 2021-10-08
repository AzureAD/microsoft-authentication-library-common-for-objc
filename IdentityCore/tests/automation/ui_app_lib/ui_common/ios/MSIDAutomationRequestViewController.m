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

#import "MSIDAutomationRequestViewController.h"
#import "MSIDAutomationTestRequest.h"

@interface MSIDAutomationRequestViewController ()

@property (strong, nonatomic) IBOutlet UIButton *requestGo;

@end

@implementation MSIDAutomationRequestViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.requestInfo.text = nil;
}

- (IBAction)go:(__unused id)sender
{
    self.requestInfo.editable = NO;
    self.requestGo.enabled = NO;
    [self.requestGo setTitle:@"Running..." forState:UIControlStateDisabled];

    NSString *jsonString = [self getConfigJsonString];
    NSDictionary *params = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (!params)
    {
        self.completionBlock(nil);
        return;
    }

    MSIDAutomationTestRequest *request = [[MSIDAutomationTestRequest alloc] initWithJSONDictionary:params error:nil];
    request.parentController = self;
    
    self.completionBlock(request);
}

#pragma mark - Private

- (NSString *)getConfigJsonString
{
    NSString *simulatorSharedDir = [NSProcessInfo processInfo].environment[@"SIMULATOR_SHARED_RESOURCES_DIRECTORY"];
    NSURL *simulatorHomeDirUrl = [[NSURL alloc] initFileURLWithPath:simulatorSharedDir];
    NSURL *cachesDirUrl = [simulatorHomeDirUrl URLByAppendingPathComponent:@"Library/Caches"];
    NSURL *fileUrl = [cachesDirUrl URLByAppendingPathComponent:@"ui_atomation_request_pipeline.txt"];

    NSString *jsonString = [NSString stringWithContentsOfFile:fileUrl.path encoding:NSUTF8StringEncoding error:nil];
    
    return jsonString;
}

@end
