//
//  FBTools.h
//
//
//  Created by fb on 16/7/26.
//  Copyright © 2016年 ARSeeds. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wdocumentation"

@interface FBTools : NSObject


+ (BOOL)validString:(NSString*)string;


#pragma mark -- file
/**
 *  转化大小
 *
 *  @param size
 *
 *  @return 1 d
 */
+ (NSString *)stringFromSize:(uint64_t)size;


/**
 *  获取单个文件大小
 *
 *  @param path   文件路径
 *
 *  @return 1  文件大小
 */
+ (uint64_t)fileSizeAtPath:(NSString *)path;


/**
 *  获取目录大小
 *
 *  @param path   目录路径
 *
 *  @return 1  目录大小
 */
+ (uint64_t)folderSizeAtPath:(NSString *)path;


/**
 *  获取指定目录下的文件个数（包括子目录下文件，但不包括目录本身）
 *
 *  @param dirPath
 *
 *  @return 1
 */
+ (NSUInteger)numberOfSubfilesAtDir:(NSString *)dirPath;

/**
 *  判断是否是文件夹
 *
 *  @param filePath
 *
 *  @return 1
 */
+ (BOOL)isDir:(NSString *)filePath;

/**
 *  判断文件是否存在
 *
 *  @param fileName
 *
 *  @return 1
 */
+(BOOL)isExistFile:(NSString *)fileName;




/**
 *  清空 文件夹 下 指定后缀类型 文件， ext为空，则清空所有
 *
 *  @param ext
 *  @param dirPath
 */
+ (void)clearContentsOfExtension:(NSString*)ext inDir:(NSString*)dirPath;


+(NSString *)getDocumentPath;

+(NSString *)getTargetPathWithBasepath:(NSString *)name subpath:(NSString *)subpath;

+(NSArray *)getTargetFloderPathWithBasepath:(NSString *)name subpatharr:(NSArray *)arr;

+(NSString *)getTempFolderPathWithBasepath:(NSString *)name;



#pragma mark -- string
+ (NSString *)firstCharacterWithString:(NSString *)string;

+ (NSDictionary *)dictionaryOrderByCharacterWithOriginalArray:(NSArray *)array;

+ (NSString *)currentDateWithFormat:(NSString *)format;

+ (NSString *)timeIntervalFromLastTime:(NSString *)lastTime
                        lastTimeFormat:(NSString *)format1
                         ToCurrentTime:(NSString *)currentTime
                     currentTimeFormat:(NSString *)format2;

+ (NSString*)timeIntervalFromNowToLastTime:(NSString*)lastTime lastTimeFormat:(NSString *)format;

+ (NSString *)timeIntervalFromLastTime:(NSDate *)lastTime ToCurrentTime:(NSDate *)currentTime;

+ (NSString*)stringFromNowToDate:(NSTimeInterval)time;


#pragma mark -- regex
/*
 *  是否是纯数字
 */
+ (BOOL)validNumber:(NSString*)string;

/**
 *  手机号格式验证
 *
 *  @param mobile
 *
 *  @return 1
 */
+ (BOOL)validMobile:(NSString *)mobile;

/**
 *  邮件地址验证
 *
 *  @param email
 *
 *  @return 1
 */
+ (BOOL)validEmail:(NSString *)email;

+ (UIImage *)filterWithOriginalImage:(UIImage *)image filterName:(NSString *)name;

+ (UIImage *)blurWithOriginalImage:(UIImage *)image blurName:(NSString *)name radius:(NSInteger)radius;


+ (UIImage *)colorControlsWithOriginalImage:(UIImage *)image
                                 saturation:(CGFloat)saturation
                                 brightness:(CGFloat)brightness
                                   contrast:(CGFloat)contrast;

+ (UIVisualEffectView *)effectViewWithFrame:(CGRect)frame;



#pragma mark -- screen shot
/**
 *  截屏
 *
 *  @return 1
 */
+ (UIImage *)shotScreen;

/**
 *  指定View截图
 *
 *  @param view
 *
 *  @return 1
 */
+ (UIImage *)shotWithView:(UIView *)view;

+ (UIImage *)shotWithView:(UIView *)view scope:(CGRect)scope;

+ (UIImage *)compressOriginalImage:(UIImage *)image toSize:(CGSize)size;


+ (NSData *)compressOriginalImage:(UIImage *)image toMaxDataSizeKBytes:(CGFloat)size;

/**
 *  获取IP地址
 *
 *  @return 1
 */
+ (NSString *)getIPAddress;




#pragma mark -- uiview

/**
 *  view shake animation
 *
 *  @param view 
 */
+ (void)shakeAnimationForView:(UIView *)view;


+ (UIView*)noMoreDataFooterView;



#pragma mark -- array

+ (NSArray*)getRandomObjsByCount:(NSUInteger)count inArray:(NSArray*)array;




#pragma mark -- system

+ (NSString*)appName;

/**
 *  获取app 版本，不带点
 *
 *  @return 1 @"100"
 */
+ (NSString*)appVersionWithoutDots;

/**
 *  获取app 版本
 *
 *  @return 1 @"1.0.1"
 */
+ (NSString*)appVersionWithDots;


+ (NSInteger)appIntVersion;

+ (float)appFloatVersion;



#pragma mark -- encode using runtime
+ (void)encodeInstance:(id)instance instanceClass:(Class)instanceClass withCoder:(NSCoder*)encoder;
+ (void)decodeInstance:(id)instance instanceClass:(Class)instanceClass withCoder:(NSCoder*)decoder;




#pragma mark -- video transform
+ (void)transformMovWithAsset:(AVURLAsset*)asset toMP4WithDestPath:(NSString*)destPath completion:(void(^)(NSString *Mp4FilePath, NSError* err))completeBlock;
+ (void)transformMovWithSourceUrl:(NSString *)movFilePath toMP4WithDestPath:(NSString*)destPath completion:(void(^)(NSString *Mp4FilePath, NSError* err))completeBlock;
+ (void) getVideoThumbnailImage:(NSString *)videoURL completeBlk:(void(^)(UIImage* image))completeBlk;



//-- 获取指定长度的随机数字字符串
+ (NSString *)getRandomPINString:(NSInteger)length;

//-- 获取指定长度的随机字母+数字字符串
+(NSString*)generateRandomString:(NSInteger)length;


/**
 *  正则匹配返回符合要求的字符串 数组
 *
 *  @param string   需要匹配的字符串
 *  @param regexStr 正则表达式
 *
 *  @return 符合要求的字符串 数组 (按(),分级,正常0)
 */


+ (NSArray *)matchString:(NSString *)string toRegexString:(NSString *)regexStr;
@end
