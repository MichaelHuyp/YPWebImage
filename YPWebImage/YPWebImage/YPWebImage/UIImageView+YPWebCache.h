//
//  UIImageView+YPWebCache.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageCompat.h"
#import "YPWebImageManager.h"


@interface UIImageView (YPWebCache)

/**
 *  根据url异步下载图片,并带有缓存策略
 *
 *  @param url         图片url
 *  @param placeholder 占位图片
 */
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder;

/**
 * 取消当前图片的下载
 */
- (void)cancelCurrentImageLoad;

@end
