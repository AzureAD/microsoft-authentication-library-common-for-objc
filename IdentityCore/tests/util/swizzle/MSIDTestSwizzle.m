//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDTestSwizzle.h"

#import <objc/runtime.h>


static NSMutableArray<MSIDTestSwizzle *> *s_currentMonkeyPatches = nil;

@interface MSIDTestSwizzle ()
{
@public
    dispatch_block_t _block;
    IMP _originalImp;
}

- (BOOL)matchesObject:(id)obj
             selector:(SEL)sel;

@end

@implementation MSIDTestSwizzle
{
    Class _class;
    SEL _sel;
    Method _m;
    BOOL _instance;
}

- (void)dealoc
{
    if (_block)
    {
        IMP mockImp = imp_implementationWithBlock(_block);
        imp_removeBlock(mockImp);
        _block = nil;
    }
}

+ (void)initialize
{
    s_currentMonkeyPatches = [NSMutableArray new];
}

+ (void)reset
{
    @synchronized (s_currentMonkeyPatches)
    {
        // We want to go through this backwards like a stack in case someone
        // changed a method multiple times and it gets restored to its
        // original implementation
        for (NSInteger i = s_currentMonkeyPatches.count - 1; i >= 0; i--)
        {
            MSIDTestSwizzle *patch = s_currentMonkeyPatches[i];
            method_setImplementation(patch->_m, patch->_originalImp);
        }
        
        [s_currentMonkeyPatches removeAllObjects];
    }
}

+ (MSIDTestSwizzle *)instanceMethod:(SEL)sel class:(Class)class impl:(IMP)impl
{
    return [[MSIDTestSwizzle instanceMethod:sel class:class] swizzle:impl];
}

+ (MSIDTestSwizzle *)classMethod:(SEL)sel class:(Class)cls impl:(IMP)impl
{
    return [[MSIDTestSwizzle classMethod:sel class:cls] swizzle:impl];
}


+ (MSIDTestSwizzle *)instanceMethod:(SEL)sel class:(Class)cls block:(id)block
{
    return [[MSIDTestSwizzle instanceMethod:sel class:cls] swizzle:imp_implementationWithBlock(block)];
}

+ (MSIDTestSwizzle *)classMethod:(SEL)sel class:(Class)cls block:(id)block
{
    return [[MSIDTestSwizzle classMethod:sel class:cls] swizzle:imp_implementationWithBlock(block)];
}

+ (MSIDTestSwizzle *)instanceMethod:(SEL)sel
                              class:(Class)class
{
    MSIDTestSwizzle *p = [MSIDTestSwizzle new];
    p->_m = class_getInstanceMethod(class, sel);
    if (!p->_m)
    {
        @throw @"Instance method not found";
    }
    p->_sel = sel;
    p->_class = class;
    p->_instance = YES;
    return p;
}

+ (MSIDTestSwizzle *)classMethod:(SEL)sel
                           class:(Class)class
{
    MSIDTestSwizzle *p = [MSIDTestSwizzle new];
    p->_m = class_getClassMethod(class, sel);
    if (!p->_m)
    {
        @throw @"Class method not found";
    }
    p->_sel = sel;
    p->_class = class;
    p->_instance = NO;
    return p;
}

- (MSIDTestSwizzle *)swizzle:(IMP)impl
{
    @synchronized (s_currentMonkeyPatches)
    {
        _originalImp = method_setImplementation(_m, impl);
        [s_currentMonkeyPatches addObject:self];
    }
    
    return self;
}

- (BOOL)matchesObject:(id)obj selector:(SEL)sel
{
    if (!sel_isEqual(sel, _sel))
    {
        return NO;
    }
    
    if (_instance)
    {
        return [obj isKindOfClass:_class];
    }
    else
    {
        return obj == _class;
    }
}

- (IMP)originalIMP
{
    return _originalImp;
}

- (SEL)sel
{
    return _sel;
}

- (void)makePermanent
{
    @synchronized (s_currentMonkeyPatches)
    {
        [s_currentMonkeyPatches removeObject:self];
    }
}

@end
