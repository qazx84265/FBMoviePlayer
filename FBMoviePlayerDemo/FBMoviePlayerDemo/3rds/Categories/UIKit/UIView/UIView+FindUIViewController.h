//
//  UIView+FindUIViewController.h
//  tiny design
//
//  Created by FB on 2017/7/7.
//  Copyright © 2017年 FB. All rights reserved.
//


#import <UIKit/UIKit.h>

@interface UIView (FindUIViewController)
- (UIViewController *) firstAvailableUIViewController;
- (id) traverseResponderChainForUIViewController;
@end
