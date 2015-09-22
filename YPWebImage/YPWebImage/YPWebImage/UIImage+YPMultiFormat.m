//
//  UIImage+YPMultiFormat.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "UIImage+YPMultiFormat.h"
#import "UIImage+YPGIF.h"
#import "NSData+YPImageContentType.h"
#import <ImageIO/ImageIO.h>

@implementation UIImage (YPMultiFormat)


+ (UIImage *)imageWithMultiFormatData:(NSData *)data
{
    if (!data) { // 如果传入的数据为空直接返回nil
        return nil;
    }
    // 如果有数据
    UIImage *image;
    // 根据传入的数据获取图片的类型
    NSString *imageContentType = [NSData contentTypeForImageData:data];
    if ([imageContentType isEqualToString:@"image/gif"]) { // 如果分析数据得出图片格式为gif图片
        // 那么图片就以gif的数据加载方式获取图片
        image = [UIImage animatedGIFWithData:data];
    } else { // 如果image格式不是gif格式
        // 以普通数据形式设置图片
        image = [[UIImage alloc] initWithData:data];
        // 根据数据获取图片的绘制方向
        UIImageOrientation orientation = [self imageOrientationFromImageData:data];
        if (orientation != UIImageOrientationUp) { // 如果绘制方向不是默认的向上方向
            // 图片就根据图片的伸缩度以及方向进行改变
            image = [UIImage imageWithCGImage:image.CGImage
                                        scale:image.scale
                                  orientation:orientation];
        }
    }
    
    // 返回处理后的图片
    return image;

}

/**
 *  根据数据获取图片的绘制方向
 */
+ (UIImageOrientation)imageOrientationFromImageData:(NSData *)imageData {
    // 声明一个UIImageOrientation对象,默认值为UIImageOrientationUp
    UIImageOrientation result = UIImageOrientationUp;
    // 根据图片数据开启图形资源上下文
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (imageSource) { // 如果图形资源上下文不为空
        // 根据图形资源上下文,以及第0的索引获取图形属性字典
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
        if (properties) { // 如果图形属性字典有值
            /**
             *  搞一个CF对象指针
             */
            CFTypeRef val;
            // 设置一个可交换方向的int值
            int exifOrientation;
            // 根据图形属性字典获取到kCGImagePropertyOrientation绘制方向属性
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) { // 如果val值不为空
                // 获得一个CFNumber对象转换为指定类型的值,存到exifOrientation中
                CFNumberGetValue(val, kCFNumberIntType, &exifOrientation);
                // 根据exifOrientation的值设置绘制方向
                result = [self exifOrientationToiOSOrientation:exifOrientation];
            }
            // 释放properties CF字典
            CFRelease((CFTypeRef) properties);
        }
        // 释放图形资源上下文
        CFRelease(imageSource);
    }
    // 返回绘制方向
    return result;
}

+ (UIImageOrientation)exifOrientationToiOSOrientation:(int)exifOrientation {
    // 默认绘制方向向上
    UIImageOrientation orientation = UIImageOrientationUp;
    switch (exifOrientation) { // 根据方向参数设置绘制方向
        case 1:
            orientation = UIImageOrientationUp;
            break;
            
        case 3:
            orientation = UIImageOrientationDown;
            break;
            
        case 8:
            orientation = UIImageOrientationLeft;
            break;
            
        case 6:
            orientation = UIImageOrientationRight;
            break;
            
        case 2:
            orientation = UIImageOrientationUpMirrored;
            break;
            
        case 4:
            orientation = UIImageOrientationDownMirrored;
            break;
            
        case 5:
            orientation = UIImageOrientationLeftMirrored;
            break;
            
        case 7:
            orientation = UIImageOrientationRightMirrored;
            break;
        default:
            break;
    }
    return orientation;
}



@end
