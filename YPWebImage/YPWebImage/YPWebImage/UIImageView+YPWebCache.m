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
        
        // 取消强循环引用
        __weak __typeof(self)wself = self;
        
        // 由YPWebImageManager负责图片的获取
        id <YPWebImageOperation> operation = [[YPWebImageManager sharedManager] downloadImageWithURL:url completed:^(UIImage *image, NSError *error, YPImageCacheType cacheType, BOOL finished, NSURL *imageURL) { // 这是图片下载完成后回调的block
            
            // 如果当前UIimageView对象为空直接返回
            if (!wself) return;
            
            dispatch_main_sync_safe(^{ // 强行回到同步主线程
                // 如果当前UIimageView对象为空直接返回
                if (!wself) return;
                
                if (image) { // 图片不为空
                    // 设置图片
                    wself.image = image;
                    // 这个方法是异步执行的,setNeedsLayout会默认调用layoutSubViews
                    [wself setNeedsLayout];
                } else { // 如果图片为空
                    wself.image = placeholder;
                    [wself setNeedsDisplay];
                }
            });
            
        }];
        // 将刚刚取得的operation以UIImageViewImageLoad关键字添加到操作字典中
        [self setImageLoadOperation:operation forKey:@"UIImageViewImageLoad"];
    }
}

/**
 *  就算你输成字符串我也不怪你
 */
- (void)setImageWithURLStr:(NSString *)url placeholderImage:(UIImage *)placeholder
{
    [self setImageWithURL:[NSURL URLWithString:url] placeholderImage:placeholder];
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
