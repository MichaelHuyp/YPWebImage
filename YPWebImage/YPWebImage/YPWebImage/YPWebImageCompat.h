//
//  YPWebImageCompat.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#if OS_OBJECT_USE_OBJC
#undef SDDispatchQueueRelease
#undef SDDispatchQueueSetterSementics
#define SDDispatchQueueRelease(q)
#define SDDispatchQueueSetterSementics strong
#else
#undef SDDispatchQueueRelease
#undef SDDispatchQueueSetterSementics
#define SDDispatchQueueRelease(q) (dispatch_release(q))
#define SDDispatchQueueSetterSementics assign
#endif

typedef void(^YPWebImageNoParamsBlock)();

#define dispatch_main_sync_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_sync(dispatch_get_main_queue(), block);\
}

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}