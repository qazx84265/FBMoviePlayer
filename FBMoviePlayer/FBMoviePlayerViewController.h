//
//  FBMoviePlayerViewController.h
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FBMoviePlayerViewController : UIViewController
/**************************************
 *     initializer not avaliable      *
 **************************************/
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;


/**************************************
 *     initializer  avaliable         *
 **************************************/
+ (instancetype)moviePlayerWithMovie:(NSString*)moviePath;
@end
