//
//  UIScrollView+FBRefresh.h
//  ARSeek
//
//  Created by FB on 16/8/25.
//  Copyright © 2016年 ARSeeds. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef NS_ENUM(NSInteger, ScrollViewRefreshType) {
    ScrollViewRefreshType_refresh = 0, //下拉刷新
    ScrollViewRefreshType_loadmore //上拉加载更多
};


@interface UIScrollView(FBRefresh)

@property (nonatomic, assign) ScrollViewRefreshType refreshType;

@end
