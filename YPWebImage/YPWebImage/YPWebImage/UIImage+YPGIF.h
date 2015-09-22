//
//  UIImage+YPGIF.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (YPGIF)

/**
 *  以gif的数据加载方式获取图片
 */
+ (UIImage *)animatedGIFWithData:(NSData *)data;

@end
