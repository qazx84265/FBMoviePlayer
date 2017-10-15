//
//  UIScrollView+FBRefresh.m
//  ARSeek
//
//  Created by FB on 16/8/25.
//  Copyright © 2016年 ARSeeds. All rights reserved.
//

#import "UIScrollView+FBRefresh.h"


static char FBScrollViewRefreshType;

@implementation UIScrollView(FBRefresh)

- (void)setRefreshType:(ScrollViewRefreshType)refreshType {
    objc_setAssociatedObject(self, &FBScrollViewRefreshType, [NSNumber numberWithInteger:refreshType], OBJC_ASSOCIATION_RETAIN);
}

- (ScrollViewRefreshType)refreshType {
    NSNumber* number = objc_getAssociatedObject(self, &FBScrollViewRefreshType);
    return [number integerValue];
}


@end
