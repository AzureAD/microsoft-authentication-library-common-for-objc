#------------------------------------------------------------------------------
#
# Copyright (c) Microsoft Corporation.
# All rights reserved.
#
# This code is licensed under the MIT License.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files(the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions :
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#------------------------------------------------------------------------------

"""Execute production password helpers against deterministic XCUI doubles.

Run on macOS with Xcode: python3 IdentityCore/tests/automation/test_password_transition.py
An optional source path allows the same scenarios to reproduce a baseline failure.
Only XCUI and time are doubled; the Objective-C helper bodies are compiled unchanged.
"""

from pathlib import Path
import subprocess
import sys
import tempfile


HARNESS = r'''
#import <Foundation/Foundation.h>

static NSInteger MSIDTick;
static const NSTimeInterval MSIDPasswordEntryPollingTimeout = 45;
static const NSTimeInterval MSIDPasswordEntryPollingInterval = 1;

@interface MSIDTestDate : NSObject
@property NSInteger deadline;
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)interval;
- (NSTimeInterval)timeIntervalSinceNow;
@end
@implementation MSIDTestDate
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)interval
{
    MSIDTestDate *date = [self new];
    date.deadline = MSIDTick + interval;
    return date;
}
- (NSTimeInterval)timeIntervalSinceNow
{
    return self.deadline - MSIDTick;
}
@end

@interface MSIDTestThread : NSObject
+ (void)sleepForTimeInterval:(NSTimeInterval)interval;
@end
@implementation MSIDTestThread
+ (void)sleepForTimeInterval:(NSTimeInterval)interval
{
    MSIDTick++;
}
@end

@class MSIDTestApp;
@interface MSIDTestElement : NSObject
@property BOOL present;
@property BOOL enabled;
@property BOOL hittable;
@property BOOL staleHeader;
@property NSInteger taps;
@property (copy) NSString *title;
@property (weak) MSIDTestApp *app;
@property (strong) NSMutableDictionary<NSString *, MSIDTestElement *> *elements;
@property (strong) MSIDTestElement *firstMatch;
- (BOOL)exists;
- (BOOL)isEnabled;
- (BOOL)isHittable;
- (MSIDTestElement *)objectForKeyedSubscript:(NSString *)key;
- (void)msidTap;
@end
@interface MSIDTestApp : NSObject
@property (strong) MSIDTestApp *webViews;
@property (strong) MSIDTestElement *buttons;
@property (strong) MSIDTestElement *staticTexts;
@property (strong) MSIDTestElement *secureTextFields;
@property (strong) MSIDTestElement *keyboards;
@property (strong) MSIDTestElement *field;
@property (strong) MSIDTestElement *header;
@property (strong) MSIDTestElement *keyboard;
@property (copy) NSString *password;
@property (copy) NSString *typed;
@property BOOL selected;
@property BOOL otherWaysSelected;
@property BOOL initiallyReady;
@property BOOL neverReady;
@property BOOL setupCalled;
@property NSInteger selectionTick;
@property NSInteger headerReads;
@end
@implementation MSIDTestApp
@end
@implementation MSIDTestElement
- (BOOL)exists
{
    if (self == self.app.field)
    {
        return self.app.initiallyReady || (self.app.selected && !self.app.neverReady &&
                                          MSIDTick >= self.app.selectionTick + 3);
    }
    return self.present;
}
- (BOOL)isEnabled
{
    return self.enabled;
}
- (BOOL)isHittable
{
    if (self.staleHeader)
    {
        self.app.headerReads++;
        if (self.app.selected || self.app.initiallyReady)
        {
            [NSException raise:@"StaleHeading" format:@"Queried departing Verify-email heading"];
        }
    }
    return self.hittable;
}
- (MSIDTestElement *)objectForKeyedSubscript:(NSString *)key
{
    return self.elements[key] ?: [MSIDTestElement new];
}
- (void)msidTap
{
    self.taps++;
    if (self == self.app.header)
    {
        self.app.keyboard.present = NO;
    }
    else if ([self.title isEqualToString:@"Other ways to sign in"])
    {
        self.present = NO;
        self.app.otherWaysSelected = YES;
        self.app.webViews.buttons.elements[@"Use my password"].present = YES;
    }
    else
    {
        self.app.selected = YES;
        self.app.selectionTick = MSIDTick;
        // Intentionally leave the selected control and old header in the tree.
    }
}
@end

@compatibility_alias XCUIElement MSIDTestElement;
@compatibility_alias XCUIApplication MSIDTestApp;
#define NSDate MSIDTestDate
#define NSThread MSIDTestThread
#define XCTFail(message) [NSException raise:@"PasswordTimeout" format:@"%@", message]
#define XCTWaiterResultCompleted 0

@interface MSIDBaseUITest : NSObject
@property (strong) MSIDTestApp *primaryAccount;
- (void)enterPassword:(NSString *)password app:(XCUIApplication *)app;
- (void)enterPassword:(NSString *)password app:(XCUIApplication *)app isMainApp:(BOOL)isMainApp;
- (void)setupPassword:(NSString *)password app:(XCUIApplication *)app;
- (void)tapElementAndWaitForKeyboardToAppear:(XCUIElement *)element app:(XCUIApplication *)app;
- (void)enterText:(XCUIElement *)element isMainApp:(BOOL)isMainApp text:(NSString *)text;
- (NSInteger)waitForElementsAndContinueIfNotAppear:(XCUIElement *)element timeout:(NSTimeInterval)timeout;
@end
@implementation MSIDBaseUITest
- (void)enterPassword:(NSString *)password app:(XCUIApplication *)app
{
    [self enterPassword:password app:app isMainApp:YES];
}
- (void)setupPassword:(NSString *)password app:(XCUIApplication *)app
{
    app.setupCalled = YES;
}
- (void)tapElementAndWaitForKeyboardToAppear:(XCUIElement *)element app:(XCUIApplication *)app
{
    NSCAssert(element == app.field && element.exists && element.isHittable, @"Password not ready");
}
- (void)enterText:(XCUIElement *)element isMainApp:(BOOL)isMainApp text:(NSString *)text
{
    element.app.typed = text;
}
- (NSInteger)waitForElementsAndContinueIfNotAppear:(XCUIElement *)element timeout:(NSTimeInterval)timeout
{
    return element.exists ? XCTWaiterResultCompleted : 1;
}
// PRODUCTION_METHODS
@end

static MSIDTestElement *MSIDElement(MSIDTestApp *app, NSString *title)
{
    MSIDTestElement *element = [MSIDTestElement new];
    element.app = app;
    element.title = title;
    element.present = YES;
    element.enabled = YES;
    element.hittable = YES;
    element.elements = [NSMutableDictionary new];
    return element;
}

static void MSIDRun(NSString *title, BOOL staticText, BOOL ready, BOOL timeout, BOOL keyboard)
{
    MSIDTick = 0;
    MSIDTestApp *app = [MSIDTestApp new];
    app.password = @"test-password";
    app.webViews = [MSIDTestApp new];
    app.buttons = MSIDElement(app, @"buttons");
    app.staticTexts = MSIDElement(app, @"texts");
    app.webViews.buttons = MSIDElement(app, @"web-buttons");
    app.webViews.staticTexts = MSIDElement(app, @"web-texts");
    app.secureTextFields = MSIDElement(app, @"secure");
    app.keyboards = MSIDElement(app, @"keyboards");
    app.field = MSIDElement(app, @"password");
    app.secureTextFields.firstMatch = app.field;
    app.header = MSIDElement(app, @"Verify your email");
    app.header.staleHeader = YES;
    app.webViews.staticTexts.elements[app.header.title] = app.header;
    app.keyboard = MSIDElement(app, @"keyboard");
    app.keyboard.present = keyboard;
    app.keyboards.firstMatch = app.keyboard;
    app.initiallyReady = ready;
    app.neverReady = timeout;
    MSIDTestElement *option = MSIDElement(app, title);
    (staticText ? app.webViews.staticTexts : app.webViews.buttons).elements[title] = option;
    MSIDTestElement *autofill = MSIDElement(app, @"Use your password");
    app.buttons.elements[autofill.title] = autofill;
    app.staticTexts.elements[autofill.title] = autofill;
    if ([title isEqualToString:@"Other ways to sign in"])
    {
        MSIDTestElement *direct = MSIDElement(app, @"Use my password");
        direct.present = NO;
        app.webViews.buttons.elements[direct.title] = direct;
    }
    MSIDBaseUITest *test = [MSIDBaseUITest new];
    test.primaryAccount = app;
    @try
    {
        [test aadEnterPassword:app];
        NSCAssert(!timeout, @"Expected a timeout");
    }
    @catch (NSException *exception)
    {
        if (!timeout || ![exception.name isEqualToString:@"PasswordTimeout"])
        {
            @throw;
        }
    }
    if (!timeout)
    {
        NSCAssert([app.typed isEqualToString:@"test-password\n"], @"Password not entered");
        NSCAssert(app.setupCalled, @"Password-reset handling skipped");
    }
    NSCAssert(option.taps == (ready ? 0 : 1), @"Repeated or eager selection");
    NSCAssert(autofill.taps == 0, @"Selected a native AutoFill control");
    NSCAssert(app.header.taps == (!ready && keyboard ? 1 : 0), @"Wrong keyboard dismissal");
    if (ready)
    {
        NSCAssert(app.headerReads == 0, @"Inspected stale heading despite ready field");
    }
    printf("PASS %s%s%s%s\n", title.UTF8String, staticText ? " static" : "",
           ready ? " already-ready" : "", timeout ? " timeout" : "");
}

int main(void)
{
    @autoreleasepool
    {
        for (NSString *title in @[@"Use my password", @"Use your password",
                                  @"Use your password instead", @"Other ways to sign in"])
        {
            MSIDRun(title, NO, NO, NO, YES);
        }
        MSIDRun(@"Use your password", YES, NO, NO, YES);
        MSIDRun(@"Use your password", NO, YES, NO, YES);
        MSIDRun(@"Use your password", NO, NO, YES, YES);
        MSIDRun(@"Use your password", NO, NO, NO, NO);
    }
    return 0;
}
'''


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        Path(__file__).parent / "ui_tests_lib/MSIDBaseUITest.m"
    )
    text = source.read_text()
    methods = []
    for selector in (
        "- (void)aadEnterPassword:",
        "- (BOOL)dismissKeyboardIfVerifyEmailPagePresentInApp:",
        "- (BOOL)tapPasswordSelectionButtonIfPresentInApp:",
        "- (void)enterPassword:(NSString *)password app:(XCUIApplication *)application isMainApp:",
    ):
        start = text.index(selector)
        end = text.index("\n}\n", start) + 3
        methods.append(text[start:end])
    with tempfile.TemporaryDirectory(prefix="msid-password-transition-") as directory:
        harness = Path(directory) / "regression.m"
        executable = Path(directory) / "regression"
        harness.write_text(HARNESS.replace("// PRODUCTION_METHODS", "\n".join(methods)))
        subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-framework", "Foundation",
             str(harness), "-o", str(executable)],
            check=True,
        )
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
