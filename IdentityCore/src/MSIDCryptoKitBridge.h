#if defined(MSAL_COCOAPOD)
#import <MSAL/MSAL-Swift.h>
#elif defined(ONEAUTH_COCOAPOD)
#import <whatever>
#else
#import "IdentityCore-Swift.h"
#endif
