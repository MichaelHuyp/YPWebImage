//
//  UIImage+YPForceDecode.h
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (YPForceDecode)

/**
 *  对图片进行解码操作
 */
+ (UIImage *)decodedImageWithImage:(UIImage *)image;

@end
