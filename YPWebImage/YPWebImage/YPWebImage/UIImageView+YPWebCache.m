//
//  UIImageView+YPWebCache.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "UIImageView+YPWebCache.h"
#import <objc/runtime.h>
#import "UIView+YPWebCacheOperation.h"

@implementation UIImageView (YPWebCache)

/** 图片url关联key */
static char imageURLKey;


- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder
{
    // 1.取消当前图片的下载
    [self cancelCurrentImageLoad];
    
    // 2.将所要下载的图片的url关联起来
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 3.先设置一张占位图片(异步)
    dispatch_main_async_safe(^{
        self.image = placeholder;
    });
    
    // 4.下载图片
    if (url) { // 如果url有值
        // 下载图片 返回下载的操作
        id <YPWebImageOperation> operation = [[YPWebImageManager sharedManager] downloadImageWithURL:url];
        // 将刚刚取得的operation以UIImageViewImageLoad关键字添加到操作字典中
        [self setImageLoadOperation:operation forKey:@"UIImageViewImageLoad"];
    }
}

/**
 *  取消当前图片的下载
 */
- (void)cancelCurrentImageLoad
{
    // 根据UIImageViewImageLoad这个Key值取消当前图片的加载
    [self cancelImageLoadOperationWithKey:@"UIImageViewImageLoad"];
}

@end
