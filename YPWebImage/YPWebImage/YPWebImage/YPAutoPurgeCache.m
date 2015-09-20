//
//  YPAutoPurgeCache.m
//  YPWebImage
//
//  Created by 胡云鹏 on 15/9/20.
//  Copyright (c) 2015年 MichaelPPP. All rights reserved.
//

#import "YPAutoPurgeCache.h"

@implementation YPAutoPurgeCache

- (id)init
{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAllObjects) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    
}

@end
