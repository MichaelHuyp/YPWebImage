//
//  YPWebImageCombinedOperation.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageCombinedOperation.h"

@implementation YPWebImageCombinedOperation

/**
 *  重写cancelBlock的set方法
 */
- (void)setCancelBlock:(YPWebImageNoParamsBlock)cancelBlock
{
    // 检查一下操作是否已经取消了,那么我们只需要回调cancelBlock
    if (self.isCancelled) { // 如果操作已经取消了
        if (cancelBlock) { // 直接回调cancelBlock
            cancelBlock();
        }
        // 不要忘记把cancelBlock设置为空,除此之外的话会导致崩溃
        _cancelBlock = nil;
    } else { // 如果操作没有取消
        // 正常进行set方法
        _cancelBlock = [cancelBlock copy];
    }
}

/**
 *  实现cancel协议
 */
- (void)cancel
{
    // 将取消这个flag设置为YES
    self.cancelled = YES;
    
    if (self.cacheOperation) { // 如果缓存操作有值
        // 将这个操作取消
        [self.cacheOperation cancel];
        // 将这个操作指针设置为nil
        self.cacheOperation = nil;
    }
    
    if (self.cancelBlock) { // 触发取消的回调block
        self.cancelBlock();
        // 将block指针设置为nil
        _cancelBlock = nil;
    }
}

@end
