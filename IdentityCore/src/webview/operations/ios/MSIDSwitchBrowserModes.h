//
//  Copyright (C) Microsoft Corporation. All rights reserved.
//

#ifndef MSIDSwitchBrowserModes_h
#define MSIDSwitchBrowserModes_h

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSInteger, MSIDSwitchBrowserModes) {
    BrowserModePrivateSession = 1 << 0,
    // Add future flags here
};

#endif
