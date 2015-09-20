//
//  UIView+YPWebCacheOperation.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "UIView+YPWebCacheOperation.h"
#import <objc/runtime.h>
@implementation UIView (YPWebCacheOperation)

/** 操作字典的关键字 */
static char loadOperationKey;

/**
 *  存储操作的字典
 */
- (NSMutableDictionary *)operationDictionary {
    // 从loadOperationKey关联中取出操作字典
    NSMutableDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
    if (operations) { // 如果这个字典存在直接返回这个字典
        return operations;
    }
    // 如果字典不存在创建一个可变字典
    operations = [NSMutableDictionary dictionary];
    // 将这个可变字典以loadOperationKey关键字关联到UIView
    objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return operations;
}

- (void)setImageLoadOperation:(id)operation forKey:(NSString *)key
{
    // 存储操作时,先看看这个key有没有对应的操作,如果有取消这个操作并将其对应的key移除字典
    [self cancelImageLoadOperationWithKey:key];
    // 获取关联的操作字典
    NSMutableDictionary *operationDictionary = [self operationDictionary];
    // 将这个操作和对应的key添加到关联的操作字典中
    [operationDictionary setObject:operation forKey:key];
}

- (void)cancelImageLoadOperationWithKey:(NSString *)key
{
    // 从UIView关联中取出操作字典
    NSMutableDictionary *operationDictionary = [self operationDictionary];
    
    // 根据传入的key取出操作字典中的对应全部操作(这个操作可能是个数组)
    id operations = [operationDictionary objectForKey:key];
    
    if (operations) { // 如果操作存在
        // 先判断一下这个操作是不是个数组
        if ([operations isKindOfClass:[NSArray class]]) { // 如果是数组
            // 遍历这个数组 取出遵循了YPWebImageOperation协议的操作对象
            for (id <YPWebImageOperation> operation in operations) {
                if (operation) { // 如果取出的操作不为空
                    // 就将这个操作取消掉
                    [operation cancel];
                }
            }
        } else if ([operations conformsToProtocol:@protocol(YPWebImageOperation)]) {
            // 如果这个操作不是个数组并且遵守了SDWebImageOperation协议
            // 同样也将这个操作取消掉
            [(id <YPWebImageOperation>)operations cancel];
        }
        // 最后将这个key移除存储操作的字典
        [operationDictionary removeObjectForKey:key];
    }
}

@end





























