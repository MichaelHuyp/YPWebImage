//
//  UIImage+YPForceDecode.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "UIImage+YPForceDecode.h"

@implementation UIImage (YPForceDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image
{
    // 不要对动态图片解码(如果为动态图片,直接返回)
    if (image.images) { return image; }
    
    // 将图片转为CGImage
    CGImageRef imageRef = image.CGImage;
    
    // 取出图片的CGImageAlphaInfo信息
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(imageRef);
    BOOL anyAlpha = (alpha == kCGImageAlphaFirst ||
                     alpha == kCGImageAlphaLast ||
                     alpha == kCGImageAlphaPremultipliedFirst ||
                     alpha == kCGImageAlphaPremultipliedLast);
    // 如果anyAlpha属于上面枚举其中的一种直接返回图片
    if (anyAlpha) { return image; }
    
    // 取出图片的宽度和高度
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    
    /**
     *  开启图形上下文进行图形绘制
     *  CGContextRef CGBitmapContextCreate （
     　　void *data，
     　　size_t width，
     　　size_t height，
     　　size_t bitsPerComponent，
     　　size_t bytesPerRow，
     　　CGColorSpaceRef colorspace，
     　　CGBitmapInfo bitmapInfo
     　　）;
     
     参数data指向绘图操作被渲染的内存区域，这个内存区域大小应该为（bytesPerRow*height）个字节。如果对绘制操作被渲染的内存区域并无特别的要求，那么可以传递NULL给参数date。
     　　 参数width代表被渲染内存区域的宽度。
     　　 参数height代表被渲染内存区域的高度。
     　　 参数bitsPerComponent被渲染内存区域中组件在屏幕每个像素点上需要使用的bits位，举例来说，如果使用32-bit像素和RGB颜色格式，那么RGBA颜色格式中每个组件在屏幕每个像素点上需要使用的bits位就为32/4=8。
     　　 参数bytesPerRow代表被渲染内存区域中每行所使用的bytes位数。
     　　 参数colorspace用于被渲染内存区域的“位图上下文”。
     　　 参数bitmapInfo指定被渲染内存区域的“视图”是否包含一个alpha（透视）通道以及每个像素相应的位置，除此之外还可以指定组件式是浮点值还是整数值。
     */
    CGContextRef context = CGBitmapContextCreate(NULL, width,
                                                 height,
                                                 CGImageGetBitsPerComponent(imageRef),
                                                 0,
                                                 CGImageGetColorSpace(imageRef),
                                                 kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
    
    // 绘制图像到背景和检索新形象，现在有一个alpha层
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    
    // 根据位图上下文创建一个图像
    CGImageRef imageRefWithAlpha = CGBitmapContextCreateImage(context);
    // 将这个图像转换为UIImage
    UIImage *imageWithAlpha = [UIImage imageWithCGImage:imageRefWithAlpha];
    
    // 释放图形上下文
    CGContextRelease(context);
    // 释放CGImage
    CGImageRelease(imageRefWithAlpha);
    
    // 返回解码后的图片
    return imageWithAlpha;
}

@end
