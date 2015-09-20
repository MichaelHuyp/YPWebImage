//
//  UIView+YPWebCacheOperation.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YPWebImageManager.h"

@interface UIView (YPWebCacheOperation)
/**
 *  放置图片的下载操作(基于字典存储在UIView中)
 *
 *  @param operation 图片的下载操作
 *  @param key       存储操作的关键字
 */
- (void)setImageLoadOperation:(id)operation forKey:(NSString *)key;

/**
 *  根据key值取消当前所有的操作
 *
 *  @param key 存储操作的关键字
 */
- (void)cancelImageLoadOperationWithKey:(NSString *)key;
@end
