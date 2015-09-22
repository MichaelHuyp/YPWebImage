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
#undef YPDispatchQueueRelease
#undef YPDispatchQueueSetterSementics
#define YPDispatchQueueRelease(q)
#define YPDispatchQueueSetterSementics strong
#else
#undef YPDispatchQueueRelease
#undef YPDispatchQueueSetterSementics
#define YPDispatchQueueRelease(q) (dispatch_release(q))
#define YPDispatchQueueSetterSementics assign
#endif

/** 内联函数必须写这句话才可以被外界访问 */
extern UIImage *YPScaledImageForKey(NSString *key, UIImage *image);

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