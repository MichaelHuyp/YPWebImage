//
//  YPWebImageDownloader.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/19.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPWebImageDownloader.h"

@implementation YPWebImageDownloader

static id _instance;

+ (YPWebImageDownloader *)sharedDownloader
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

@end
