//
//  YPWebImageCompat.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageCompat.h"

/**
 *  内联函数 根据传入的key值重新设置图片的伸缩度
 */
inline UIImage *YPScaledImageForKey(NSString *key, UIImage *image) {
    
    if (!image) { // 如果图片为空直接返回nil
        return nil;
    }
    
    if ([image.images count] > 0) { // 如果图片帧数大于0
        // 搞一个可变数组
        NSMutableArray *scaledImages = [NSMutableArray array];
        
        for (UIImage *tempImage in image.images) { // 遍历图片帧数组
            // 将每一帧图片进行缩放调整处理
            [scaledImages addObject:YPScaledImageForKey(key, tempImage)];
        }
        
        // 返回动态图片,动态图片持续的时间为duration
        return [UIImage animatedImageWithImages:scaledImages duration:image.duration];
    }
    else { // 如果图片为1帧
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) { // 如果屏幕给这个方法发了消息
            // 获取当前屏幕的伸缩度
            CGFloat scale = [UIScreen mainScreen].scale;
            if (key.length >= 8) { // 如果key的长度大于等于8
                // 取出key中的@2x.字段的范围
                NSRange range = [key rangeOfString:@"@2x."];
                if (range.location != NSNotFound) { // 如果@2x.的range存在
                    // 将伸缩度置为2.0
                    scale = 2.0;
                }
                // 如果range不存在 取出key中的@3x.字段的范围
                range = [key rangeOfString:@"@3x."];
                if (range.location != NSNotFound) { // 如果@3x.的range存在
                    // 将伸缩度置为3.0
                    scale = 3.0;
                }
            }
            // 根据算好的伸缩度制定图片的比例和方向，其中方向是个枚举类。
            UIImage *scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
            // 将算好的图片设置到image上
            image = scaledImage;
        }
        // 返回算好伸缩度的image
        return image;
    }
}

