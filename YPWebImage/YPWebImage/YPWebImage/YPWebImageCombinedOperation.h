//
//  YPWebImageCombinedOperation.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YPWebImageCompat.h"
#import "YPWebImageOperation.h"

@interface YPWebImageCombinedOperation : NSObject <YPWebImageOperation>
/** 取消状态 */
@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
/** 取消的回调 */
@property (copy, nonatomic) YPWebImageNoParamsBlock cancelBlock;
/** 缓存操作 */
@property (strong, nonatomic) NSOperation *cacheOperation;
@end
