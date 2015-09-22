//
//  UIImage+YPGIF.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "UIImage+YPGIF.h"
#import <ImageIO/ImageIO.h>

@implementation UIImage (YPGIF)

+ (UIImage *)animatedGIFWithData:(NSData *)data
{
    if (!data) { // 如果数据为空直接返回nil
        return nil;
    }
    
    /**
     *  根据传入的数据生成一个图形资源上下文
     *  CGImageSource是对图像数据读取任务的抽象，通过它可以获得图像对象、缩略图、图像的属性(包括Exif信息)。
     */
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    
    // 获取资源的容量(帧数) 返回图像（不包括缩略图）图像源中的次数。
    size_t count = CGImageSourceGetCount(source);
    
    // 声明一个动态的图片
    UIImage *animatedImage;
    
    if (count <= 1) { // 如果图形资源容量小于等于1帧
        // 直接以普通图片形式加载
        animatedImage = [[UIImage alloc] initWithData:data];
    }
    else { // 如果图片大于1帧
        
        // 搞一个可变的图片数组
        NSMutableArray *images = [NSMutableArray array];
        
        /**
         *  typedef double NSTimeInterval 以秒为单位
         *  设置一个持续时间
         */
        NSTimeInterval duration = 0.0f;
        
        for (size_t i = 0; i < count; i++) {
            // 根据图像源和指定的索引,创建一个CGImage对象
            CGImageRef image = CGImageSourceCreateImageAtIndex(source, i, NULL);
            
            // 根据索引和图形资源上下文设置每张图片的持续时间,然后累加到duration中
            duration += [self frameDurationAtIndex:i source:source];
            
            // UIImage有一个imageOrientation的属性，主要作用是控制image的绘制方向
            // 将CGImage对象根据屏幕伸缩度以及image的绘制方向存到图片数组中
            [images addObject:[UIImage imageWithCGImage:image scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp]];
            
            // 释放CGImageRef对象
            CGImageRelease(image);
        }
        
        if (!duration) { // 如果duration为0
            // 设置持续时间为每帧100毫秒
            duration = (1.0f / 10.0f) * count;
        }
        
        // 将这个图片数组设置为animatedImage
        animatedImage = [UIImage animatedImageWithImages:images duration:duration];
    }
    // 释放CGImageSourceRef图形资源上下文
    CFRelease(source);
    
    // 返回动画图片
    return animatedImage;
}

/**
 *  根据索引和图形资源上下文设置持续持续时间
 *
 *  @param index  索引
 *  @param source 图形资源上下文
 *
 */
+ (float)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source {
    // 默认持续时间为0.1秒
    float frameDuration = 0.1f;
    // 在图像源的特定位置返回图像的属性字典
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil);
    // 将__CFDictionary转换成OC中的NSDictionary
    NSDictionary *frameProperties = (__bridge NSDictionary *)cfFrameProperties;
    // 获取GIF属性字典
    NSDictionary *gifProperties = frameProperties[(NSString *)kCGImagePropertyGIFDictionary];
    // 获取GIF的松开延迟时间
    NSNumber *delayTimeUnclampedProp = gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    if (delayTimeUnclampedProp) { // 如果有松开延迟时间
        // 就用gif中自己的松开延迟时间
        frameDuration = [delayTimeUnclampedProp floatValue];
    }
    else { // 如果没有松开延迟时间
        // 就获取GIF的默认延迟时间
        NSNumber *delayTimeProp = gifProperties[(NSString *)kCGImagePropertyGIFDelayTime];
        if (delayTimeProp) { // 如果有GIF的默认延迟时间
            // 就用gif的默认延迟时间
            frameDuration = [delayTimeProp floatValue];
        }
    }
    
    if (frameDuration < 0.011f) { // 当小于等于10毫秒的时候会触发bug因此小于等于10毫秒的都转为100毫秒
        frameDuration = 0.100f;
    }
    
    // 手动释放 cfFrameProperties 这个字典
    CFRelease(cfFrameProperties);
    
    // 返回这个持续时间
    return frameDuration;
}

@end

























