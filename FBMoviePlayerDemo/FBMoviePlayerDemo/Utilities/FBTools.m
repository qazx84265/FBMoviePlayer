//
//  FBTools.m
//
//
//  Created by fb on 16/7/26.
//  Copyright © 2016年 ARSeeds. All rights reserved.
//

#import "FBTools.h"

#import <ifaddrs.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

@implementation FBTools

+ (BOOL)validString:(NSString *)string {
    return string  && ![string isEqual:[NSNull idNull]] && ![string isEqualToString:@""];
}

/**
 *  转化大小
 *
 *  @param size
 *
 *  @return 1
 */
+ (NSString *)stringFromSize:(uint64_t)size {
    NSString *sizeStr = @"";
    //if (size == 0) {
        //return sizeStr;
    //}
    
    if (size/1024.0/1024.0/1024.0 < 1.0) {
        if (size/1024.0/1024.0 < 1.0) {
            if (size/1024 < 1.0) {
                sizeStr = [NSString stringWithFormat:@"%.1f b",size/1.0];
            } else {
                sizeStr  = [NSString stringWithFormat:@"%.1f Kb",size/1024.0];
            }
        } else {
            sizeStr  = [NSString stringWithFormat:@"%.1f Mb",size/1024.0/1024.0];
        }
    } else {
        sizeStr  = [NSString stringWithFormat:@"%.1f Gb",size/1024.0/1024.0/1024.0];
    }
    
    return sizeStr;
}


/**
 *  获取单个文件大小
 *
 *  @param path   文件路径
 *
 *  @return 1  文件大小
 */
+ (uint64_t)fileSizeAtPath:(NSString *)path{
    NSFileManager *fileManager=[NSFileManager defaultManager];
    uint64_t fileSize = 0;
    if([fileManager fileExistsAtPath:path]){
        fileSize=[fileManager attributesOfItemAtPath:path error:nil].fileSize;
    }
    
    return fileSize;
}


/**
 *  获取目录大小
 *
 *  @param path   目录路径
 *
 *  @return 1  目录大小
 */
+ (uint64_t)folderSizeAtPath:(NSString *)path{
    NSFileManager *fileManager=[NSFileManager defaultManager];
    uint64_t folderSize = 0;
    if ([fileManager fileExistsAtPath:path]) {
        NSArray *childerFiles=[fileManager subpathsAtPath:path];
        for (NSString *fileName in childerFiles) {
            NSString *absolutePath=[path stringByAppendingPathComponent:fileName];
            if ([[self class] isDir:absolutePath]) {
                //                folderSize += [[self class] folderSizeAtPath:absolutePath];
                continue;
            } else {
                folderSize +=[[self class] fileSizeAtPath:absolutePath];
            }
        }
    }
    
    return folderSize;
}


+ (BOOL)isDir:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManager fileExistsAtPath:filePath isDirectory:&isDir];
    
    return isExist && isDir;
}



+(BOOL)isExistFile:(NSString *)fileName
{
    NSFileManager *fileManager=[NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:fileName];
}



/**
 *  获取指定目录下的文件个数（包括子目录下文件，但不包括目录本身）
 *
 *  @param dirPath
 *
 *  @return 1
 */
+ (NSUInteger)numberOfSubfilesAtDir:(NSString *)dirPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSUInteger num = 0;
    NSArray *subFiles = [fileManager subpathsAtPath:dirPath];
    if (subFiles.count > 0) {
        for (NSString *fileName in subFiles) {
            NSString *abPath = [dirPath stringByAppendingPathComponent:fileName];
            if ([[self class] isDir:abPath]) {
                //                num += [[self class] numberOfSubfilesAtDir:abPath];
                continue;
            } else {
                num += 1;
            }
        }
    }
    
    return num;
}

//获取字符串(或汉字)首字母
+ (NSString *)firstCharacterWithString:(NSString *)string{
    NSMutableString *str = [NSMutableString stringWithString:string];
    CFStringTransform((CFMutableStringRef)str, NULL, kCFStringTransformMandarinLatin, NO);
    CFStringTransform((CFMutableStringRef)str, NULL, kCFStringTransformStripDiacritics, NO);
    NSString *pingyin = [str capitalizedString];
    return [pingyin substringToIndex:1];
}

//将字符串数组按照元素首字母顺序进行排序分组
+ (NSDictionary *)dictionaryOrderByCharacterWithOriginalArray:(NSArray *)array{
    if (array.count == 0) {
        return nil;
    }
    for (id obj in array) {
        if (![obj isKindOfClass:[NSString class]]) {
            return nil;
        }
    }
    UILocalizedIndexedCollation *indexedCollation = [UILocalizedIndexedCollation currentCollation];
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:indexedCollation.sectionTitles.count];
    //创建27个分组数组
    for (int i = 0; i < indexedCollation.sectionTitles.count; i++) {
        NSMutableArray *obj = [NSMutableArray array];
        [objects addObject:obj];
    }
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:objects.count];
    //按字母顺序进行分组
    NSInteger lastIndex = -1;
    for (int i = 0; i < array.count; i++) {
        NSInteger index = [indexedCollation sectionForObject:array[i] collationStringSelector:@selector(uppercaseString)];
        [[objects objectAtIndex:index] addObject:array[i]];
        lastIndex = index;
    }
    //去掉空数组
    for (int i = 0; i < objects.count; i++) {
        NSMutableArray *obj = objects[i];
        if (obj.count == 0) {
            [objects removeObject:obj];
        }
    }
    //获取索引字母
    for (NSMutableArray *obj in objects) {
        NSString *str = obj[0];
        NSString *key = [self firstCharacterWithString:str];
        [keys addObject:key];
    }
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:objects forKey:keys];
    return dic;
}


+ (void)clearContentsOfExtension:(NSString *)ext inDir:(NSString *)dirPath {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:dirPath error:NULL];
    NSEnumerator *e = [contents objectEnumerator];
    NSString *filename;
    while ((filename = [e nextObject])) {
        if (ext && ![ext isEqualToString:@""]) {
            if ([[filename pathExtension] isEqualToString:ext]) {
                [fm removeItemAtPath:[dirPath stringByAppendingPathComponent:filename] error:NULL];
            }
        }
        else {
            [fm removeItemAtPath:[dirPath stringByAppendingPathComponent:filename] error:NULL];
        }
    }
}



+(NSString *)getDocumentPath {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return path;
}



+(NSString *)getTargetPathWithBasepath:(NSString *)name subpath:(NSString *)subpath {
    NSString *pathstr = [[self class] getDocumentPath];
    if (name) {
        pathstr = [pathstr stringByAppendingPathComponent:name];
    }
    if (subpath) {
        pathstr = [pathstr stringByAppendingPathComponent:subpath];
    }
    
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    if(![fileManager fileExistsAtPath:pathstr]) {
        [fileManager createDirectoryAtPath:pathstr withIntermediateDirectories:YES attributes:nil error:&error];
        if(error) {
            NSLog(@"--------------->>>>>>>>>>>>>>>>>> error to create dir : %@",[error description]);
        }
    }
    
    return pathstr;
}





+(NSArray *)getTargetFloderPathWithBasepath:(NSString *)name subpatharr:(NSArray *)arr {
    NSMutableArray *patharr = [[NSMutableArray alloc]init];
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    NSString *pathstr = [[self class]getDocumentPath];
    pathstr = [pathstr stringByAppendingPathComponent:name];
    for (NSString *str in arr) {
        NSString *path = [pathstr stringByAppendingPathComponent:str];
        
        if(![fileManager fileExistsAtPath:path])
        {
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
            if(!error)
            {
                NSLog(@"%@",[error description]);
                
            }
        }
        [patharr addObject:path];
    }
    
    return patharr;
}






+(NSString *)getTempFolderPathWithBasepath:(NSString *)name {
    NSString *pathstr = [[self class]getDocumentPath];
    pathstr = [pathstr stringByAppendingPathComponent:name];
    pathstr =  [pathstr stringByAppendingPathComponent:@"Temp"];
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    if(![fileManager fileExistsAtPath:pathstr])
    {
        [fileManager createDirectoryAtPath:pathstr withIntermediateDirectories:YES attributes:nil error:&error];
        if(!error)
        {
            NSLog(@"%@",[error description]);
            
        }
    }
    return pathstr;
}



//获取当前时间
//format: @"yyyy-MM-dd HH:mm:ss"、@"yyyy年MM月dd日 HH时mm分ss秒"
+ (NSString *)currentDateWithFormat:(NSString *)format{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
    return [dateFormatter stringFromDate:[NSDate date]];
}



+ (NSString*)timeIntervalFromNowToLastTime:(NSString *)lastTime lastTimeFormat:(NSString *)format {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.dateFormat = format;
    NSDate* currDate = [NSDate date];
    NSString* currentDateString = [dateFormatter stringFromDate:currDate];
    return [[self class] timeIntervalFromLastTime:lastTime lastTimeFormat:format ToCurrentTime:currentDateString currentTimeFormat:format];
}

/**
 *  计算上次日期距离现在多久
 *
 *  @param lastTime    上次日期(需要和格式对应)
 *  @param format1     上次日期格式
 *  @param currentTime 最近日期(需要和格式对应)
 *  @param format2     最近日期格式
 *
 *  @return 1 xx分钟前、xx小时前、xx天前
 */
+ (NSString *)timeIntervalFromLastTime:(NSString *)lastTime
                        lastTimeFormat:(NSString *)format1
                         ToCurrentTime:(NSString *)currentTime
                     currentTimeFormat:(NSString *)format2{
    //上次时间
    NSDateFormatter *dateFormatter1 = [[NSDateFormatter alloc]init];
    dateFormatter1.dateFormat = format1;
    NSDate *lastDate = [dateFormatter1 dateFromString:lastTime];
    //当前时间
    NSDateFormatter *dateFormatter2 = [[NSDateFormatter alloc]init];
    dateFormatter2.dateFormat = format2;
    NSDate *currentDate = [dateFormatter2 dateFromString:currentTime];
    return [[self class] timeIntervalFromLastTime:lastDate ToCurrentTime:currentDate];
}

+ (NSString *)timeIntervalFromLastTime:(NSDate *)lastTime ToCurrentTime:(NSDate *)currentTime{
    NSTimeZone *timeZone = [NSTimeZone systemTimeZone];
    //上次时间
    NSDate *lastDate = [lastTime dateByAddingTimeInterval:[timeZone secondsFromGMTForDate:lastTime]];
    //当前时间
    NSDate *currentDate = [currentTime dateByAddingTimeInterval:[timeZone secondsFromGMTForDate:currentTime]];
    //时间间隔
    NSInteger intevalTime = [currentDate timeIntervalSinceReferenceDate] - [lastDate timeIntervalSinceReferenceDate];
    
    //秒、分、小时、天、月、年
    NSInteger minutes = intevalTime / 60;
    NSInteger hours = intevalTime / 60 / 60;
    NSInteger day = intevalTime / 60 / 60 / 24;
    NSInteger month = intevalTime / 60 / 60 / 24 / 30;
    NSInteger yers = intevalTime / 60 / 60 / 24 / 365;
    
    if (minutes <= 10) {
        return  @"刚刚";
    }else if (minutes < 60){
        return [NSString stringWithFormat: @"%ld分钟前",(long)minutes];
    }else if (hours < 24){
        return [NSString stringWithFormat: @"%ld小时前",(long)hours];
    }else if (day < 30){
        return [NSString stringWithFormat: @"%ld天前",(long)day];
    }else if (month < 12){
        NSDateFormatter * df =[[NSDateFormatter alloc]init];
        df.dateFormat = @"M月d日";
        NSString * time = [df stringFromDate:lastDate];
        return time;
    }else if (yers >= 1){
        NSDateFormatter * df =[[NSDateFormatter alloc]init];
        df.dateFormat = @"yyyy年M月d日";
        NSString * time = [df stringFromDate:lastDate];
        return time;
    }
    return @"";
}


+ (NSString*)stringFromNowToDate:(NSTimeInterval)time {
    
    NSDate* lastDate = [NSDate dateWithTimeIntervalSince1970:time];
    
    NSTimeInterval time1 = [NSDate date].timeIntervalSince1970;
    NSTimeInterval intevalTime = time1-time;
    //秒、分、小时、天、月、年
    NSInteger minutes = intevalTime / 60;
    NSInteger hours = intevalTime / 60 / 60;
    NSInteger day = intevalTime / 60 / 60 / 24;
    NSInteger month = intevalTime / 60 / 60 / 24 / 30;
    NSInteger yers = intevalTime / 60 / 60 / 24 / 365;
    
    if (minutes <= 10) {
        return  @"刚刚";
    }else if (minutes < 60){
        return [NSString stringWithFormat: @"%ld分钟前",(long)minutes];
    }else if (hours < 24){
        return [NSString stringWithFormat: @"%ld小时前",(long)hours];
    }else if (day < 30){
        return [NSString stringWithFormat: @"%ld天前",(long)day];
    }else if (month < 12){
        NSDateFormatter * df =[[NSDateFormatter alloc]init];
        df.dateFormat = @"M月d日";
        NSString * time = [df stringFromDate:lastDate];
        return time;
    }else if (yers >= 1){
        NSDateFormatter * df =[[NSDateFormatter alloc]init];
        df.dateFormat = @"yyyy年M月d日";
        NSString * time = [df stringFromDate:lastDate];
        return time;
    }
    return @"";
}



+ (BOOL)validNumber:(NSString *)string {
    BOOL res = YES;
    NSCharacterSet* tmpSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    int i = 0;
    while (i < string.length) {
        NSString * str = [string substringWithRange:NSMakeRange(i, 1)];
        NSRange range = [str rangeOfCharacterFromSet:tmpSet];
        if (range.length == 0) {
            res = NO;
            break;
        }
        i++;
    }
    return res;
}


//判断手机号码格式是否正确
+ (BOOL)validMobile:(NSString *)mobile{
    mobile = [mobile stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (mobile.length != 11)
    {
        return NO;
    }
    /**
     * 手机号码:
     * 13[0-9], 14[5,7], 15[0, 1, 2, 3, 5, 6, 7, 8, 9], 17[6, 7, 8], 18[0-9], 170[0-9]
     * 移动号段: 134,135,136,137,138,139,150,151,152,157,158,159,182,183,184,187,188,147,178,1705
     * 联通号段: 130,131,132,155,156,185,186,145,176,1709
     * 电信号段: 133,153,180,181,189,177,1700
     */
    NSString *MOBILE = @"^1(3[0-9]|4[0-9]|5[0-9]|8[0-9]|7[0-9])\\d{8}$";
//    /**
//     * 中国移动：China Mobile
//     * 134,135,136,137,138,139,150,151,152,157,158,159,182,183,184,187,188,147,178,1705
//     */
//    NSString *CM = @"(^1(3[4-9]|4[7]|5[0-27-9]|7[8]|8[2-478])\\d{8}$)|(^1705\\d{7}$)";
//    /**
//     * 中国联通：China Unicom
//     * 130,131,132,155,156,185,186,145,176,1709
//     */
//    NSString *CU = @"(^1(3[0-2]|4[5]|5[56]|7[6]|8[56])\\d{8}$)|(^1709\\d{7}$)";
//    /**
//     * 中国电信：China Telecom
//     * 133,153,180,181,189,177,1700
//     */
//    NSString *CT = @"(^1(33|53|77|8[019])\\d{8}$)|(^1700\\d{7}$)";
    
    
    NSPredicate *regextestmobile = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", MOBILE];
//    NSPredicate *regextestcm = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", CM];
//    NSPredicate *regextestcu = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", CU];
//    NSPredicate *regextestct = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", CT];
    
    if (([regextestmobile evaluateWithObject:mobile] == YES)
        /*|| ([regextestcm evaluateWithObject:mobile] == YES)
        || ([regextestct evaluateWithObject:mobile] == YES)
        || ([regextestcu evaluateWithObject:mobile] == YES)*/)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}


//利用正则表达式验证
+ (BOOL)validEmail:(NSString *)email {
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:email];
}



#pragma mark - 对图片进行滤镜处理
// 怀旧 --> CIPhotoEffectInstant                         单色 --> CIPhotoEffectMono
// 黑白 --> CIPhotoEffectNoir                            褪色 --> CIPhotoEffectFade
// 色调 --> CIPhotoEffectTonal                           冲印 --> CIPhotoEffectProcess
// 岁月 --> CIPhotoEffectTransfer                        铬黄 --> CIPhotoEffectChrome
// CILinearToSRGBToneCurve, CISRGBToneCurveToLinear, CIGaussianBlur, CIBoxBlur, CIDiscBlur, CISepiaTone, CIDepthOfField
+ (UIImage *)filterWithOriginalImage:(UIImage *)image filterName:(NSString *)name{
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [[CIImage alloc] initWithImage:image];
    CIFilter *filter = [CIFilter filterWithName:name];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    CGImageRef cgImage = [context createCGImage:result fromRect:[result extent]];
    UIImage *resultImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return resultImage;
}



#pragma mark - 对图片进行模糊处理
// CIGaussianBlur ---> 高斯模糊
// CIBoxBlur      ---> 均值模糊(Available in iOS 9.0 and later)
// CIDiscBlur     ---> 环形卷积模糊(Available in iOS 9.0 and later)
// CIMedianFilter ---> 中值模糊, 用于消除图像噪点, 无需设置radius(Available in iOS 9.0 and later)
// CIMotionBlur   ---> 运动模糊, 用于模拟相机移动拍摄时的扫尾效果(Available in iOS 9.0 and later)
+ (UIImage *)blurWithOriginalImage:(UIImage *)image blurName:(NSString *)name radius:(NSInteger)radius{
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [[CIImage alloc] initWithImage:image];
    CIFilter *filter;
    if (name.length != 0) {
        filter = [CIFilter filterWithName:name];
        [filter setValue:inputImage forKey:kCIInputImageKey];
        if (![name isEqualToString:@"CIMedianFilter"]) {
            [filter setValue:@(radius) forKey:@"inputRadius"];
        }
        CIImage *result = [filter valueForKey:kCIOutputImageKey];
        CGImageRef cgImage = [context createCGImage:result fromRect:[result extent]];
        UIImage *resultImage = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        return resultImage;
    }else{
        return nil;
    }
}




/**
 *  调整图片饱和度, 亮度, 对比度
 *
 *  @param image      目标图片
 *  @param saturation 饱和度
 *  @param brightness 亮度: -1.0 ~ 1.0
 *  @param contrast   对比度
 *
 */
+ (UIImage *)colorControlsWithOriginalImage:(UIImage *)image
                                 saturation:(CGFloat)saturation
                                 brightness:(CGFloat)brightness
                                   contrast:(CGFloat)contrast{
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [[CIImage alloc] initWithImage:image];
    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    
    [filter setValue:@(saturation) forKey:@"inputSaturation"];
    [filter setValue:@(brightness) forKey:@"inputBrightness"];
    [filter setValue:@(contrast) forKey:@"inputContrast"];
    
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    CGImageRef cgImage = [context createCGImage:result fromRect:[result extent]];
    UIImage *resultImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return resultImage;
}



//Avilable in iOS 8.0 and later
+ (UIVisualEffectView *)effectViewWithFrame:(CGRect)frame{
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
    effectView.frame = frame;
    return effectView;
}




//全屏截图
+ (UIImage *)shotScreen{
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIGraphicsBeginImageContext(window.bounds.size);
    [window.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}




//截取view生成一张图片
+ (UIImage *)shotWithView:(UIView *)view{
//    UIGraphicsBeginImageContext(view.bounds.size);
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}



//截取view中某个区域生成一张图片
+ (UIImage *)shotWithView:(UIView *)view scope:(CGRect)scope{
    CGImageRef imageRef = CGImageCreateWithImageInRect([self shotWithView:view].CGImage, scope);
    UIGraphicsBeginImageContext(scope.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, scope.size.width, scope.size.height);
    CGContextTranslateCTM(context, 0, rect.size.height);//下移
    CGContextScaleCTM(context, 1.0f, -1.0f);//上翻
    CGContextDrawImage(context, rect, imageRef);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(imageRef);
    CGContextRelease(context);
    return image;
}




//压缩图片到指定尺寸大小
+ (UIImage *)compressOriginalImage:(UIImage *)image toSize:(CGSize)size{
    UIImage *resultImage = image;
    UIGraphicsBeginImageContext(size);
    [resultImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIGraphicsEndImageContext();
    return resultImage;
}




//压缩图片到指定文件大小
+ (NSData *)compressOriginalImage:(UIImage *)image toMaxDataSizeKBytes:(CGFloat)size{
    NSData *data = UIImageJPEGRepresentation(image, 1.0);
    CGFloat dataKBytes = data.length/1000.0;
    CGFloat maxQuality = 0.9f;
    CGFloat lastData = dataKBytes;
    while (dataKBytes > size && maxQuality > 0.01f) {
        maxQuality = maxQuality - 0.01f;
        data = UIImageJPEGRepresentation(image, maxQuality);
        dataKBytes = data.length/1000.0;
        if (lastData == dataKBytes) {
            break;
        }else{
            lastData = dataKBytes;
        }
    }
    return data;
}



//获取设备 IP 地址
+ (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return address;
}


//+ (void)sectionArray:(NSArray<id>*)array completeHandler:(void (^)(NSArray* sectionDataArry, NSArray* sectionIndexArray))completeHandler {
//    if (array == nil || array.count == 0) {
//        NSLog(@"------------->>>>>>>>>>>>>>> empty array to sort.");
//        return;
//    }
//    
//    //建立索引的核心, 返回27，是a－z和＃
//    NSMutableArray* sectionIndex = [NSMutableArray new];
//    UILocalizedIndexedCollation *indexCollation = [UILocalizedIndexedCollation currentCollation];
//    [sectionIndex addObjectsFromArray:[indexCollation sectionTitles]];
//    
//    //按索引分组
//    NSInteger highSection = [sectionIndex count];
//    NSMutableArray *sortedArray = [NSMutableArray arrayWithCapacity:highSection];
//    for (int i = 0; i < highSection; i++) {
//        NSMutableArray *sectionArray = [NSMutableArray new];
//        [sortedArray addObject:sectionArray];
//    }
//    
//    
//    //按首字母分组
//    for (id arrayEle in array) {
//        NSString* string = nil;
//        if ([arrayEle isKindOfClass:[NSString class]]) {
//            string = arrayEle;
//        }
//        else if([arrayEle isKindOfClass:[ASPhoneContactModel class]]) {
//            string = ((ASPhoneContactModel*)arrayEle).name;
//        }
//        else if([arrayEle isKindOfClass:[ASUserProfileModel class]]) {
//            string = ((ASUserProfileModel*)arrayEle).nick_name;
//        }
//        else if([arrayEle isKindOfClass:[EaseUserModel class]]) {
//            EaseUserModel* um = (EaseUserModel*)arrayEle;
//            string = um.nickname ? um.nickname : um.buddy;
//        }
//        
//        if (string == nil) {
//            return;
//        }
//        
//        //获取昵称首字符
//        NSString *firstLetter = [string substringToIndex:1];
//        if ([string containChinese]) {
//            firstLetter = [string.pinyin substringToIndex:1];
//        }
//        NSInteger section = [indexCollation sectionForObject:firstLetter collationStringSelector:@selector(uppercaseString)];
//        
//        NSMutableArray *array = [sortedArray objectAtIndex:section];
//        [array addObject:string];
//    }
//    
//    //每个section内的数组排序
//    for (int i = 0; i < [sortedArray count]; i++) {
//        
//        NSArray *array = [[sortedArray objectAtIndex:i] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
//            
//            NSString *strA = nil;
//            NSString *strB = nil;
//            
//            if ([obj1 isKindOfClass:[NSString class]]) {
//                strA = obj1;
//                strB = obj2;
//            }
//            else if([obj1 isKindOfClass:[ASPhoneContactModel class]]) {
//                strA = ((ASPhoneContactModel*)obj1).name;
//                strB = ((ASPhoneContactModel*)obj2).name;
//            }
//            else if([obj1 isKindOfClass:[ASUserProfileModel class]]) {
//                strA = ((ASUserProfileModel*)obj1).nick_name;
//                strB = ((ASUserProfileModel*)obj2).nick_name;
//            }
//            else if([obj1 isKindOfClass:[EaseUserModel class]]) {
//                EaseUserModel* um1 = (EaseUserModel*)obj1;
//                EaseUserModel* um2 = (EaseUserModel*)obj2;
//                strA = um1.nickname ? um1.nickname : um1.buddy;
//                strB = um2.nickname ? um2.nickname : um2.buddy;
//            }
//            
//            if (strA == nil || strB == nil) {
//                return (NSComparisonResult)NSOrderedSame;
//            }
//            else {
//                
//                if ([strA containChinese]) {
//                    strA = strA.pinyin;
//                }
//                if ([strB containChinese]) {
//                    strB = strB.pinyin;
//                }
//                
//                strA = [strA uppercaseString];
//                strB = [strB uppercaseString];
//                
//                for (int i = 0; i < strA.length && i < strB.length; i ++) {
//                    char a = [strA characterAtIndex:i];
//                    char b = [strB characterAtIndex:i];
//                    if (a > b) {
//                        return (NSComparisonResult)NSOrderedDescending;//上升
//                    }
//                    else if (a < b) {
//                        return (NSComparisonResult)NSOrderedAscending;//下降
//                    }
//                }
//                
//                if (strA.length > strB.length) {
//                    return (NSComparisonResult)NSOrderedDescending;
//                }else if (strA.length < strB.length){
//                    return (NSComparisonResult)NSOrderedAscending;
//                }else{
//                    return (NSComparisonResult)NSOrderedSame;
//                }
//            }
//            
//        }];
//        
//        [sortedArray replaceObjectAtIndex:i withObject:[NSMutableArray arrayWithArray:array]];
//    }
//    
//    //去掉空的section
//    for (NSInteger i = [sortedArray count] - 1; i >= 0; i--) {
//        NSArray *array = [sortedArray objectAtIndex:i];
//        if ([array count] == 0) {
//            [sortedArray removeObjectAtIndex:i];
//            [sectionIndex removeObjectAtIndex:i];
//        }
//    }
//    
//    completeHandler(sortedArray, sectionIndex);
//}


#pragma mark -- uiview
+ (void)shakeAnimationForView:(UIView *) view {
    
    // 获取到当前的View
    CALayer *viewLayer = view.layer;
    
    // 获取当前View的位置
    CGPoint position = viewLayer.position;
    
    // 移动的两个终点位置
    CGPoint x = CGPointMake(position.x + 10, position.y);
    CGPoint y = CGPointMake(position.x - 10, position.y);
    
    // 设置动画
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    
    // 设置运动形式
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    
    // 设置开始位置
    [animation setFromValue:[NSValue valueWithCGPoint:x]];
    
    // 设置结束位置
    [animation setToValue:[NSValue valueWithCGPoint:y]];
    
    // 设置自动反转
    [animation setAutoreverses:YES];
    
    // 设置时间
    [animation setDuration:.06];
    
    // 设置次数
    [animation setRepeatCount:3];
    
    // 添加上动画
    [viewLayer addAnimation:animation forKey:nil];
}



+ (NSArray*)getRandomObjsByCount:(NSUInteger)count inArray:(NSArray *)array {
    
    if (count <= 0) {
        return nil;
    }
    
    NSMutableIndexSet *picks = [NSMutableIndexSet indexSet];
    do {
        int idx = arc4random() % array.count;
        if (![picks containsIndex:idx]) {
            [picks addIndex:arc4random() % array.count];
        }
    } while (picks.count != 3);
    
    NSMutableArray* randoms = [NSMutableArray arrayWithCapacity:count];
    [picks enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [randoms addObject:[array objectAtIndex:idx]];
    }];
    
    return [NSArray arrayWithArray:randoms];
}

+ (UIView*)noMoreDataFooterView {
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kSCREEN_WIDTH, 25)];
    label.backgroundColor = [UIColor ColorWithHexString:@"#f2f2f2"];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor ColorWithHexString:@"#999999"];
    label.text = @"无更多内容";
    label.font = [UIFont systemFontOfSize:12.0f];
    
    return label;
}


#pragma mark -- system

+ (NSString*)appName {
    NSString* appName = @"照见";
    NSDictionary* dic = [NSBundle mainBundle].infoDictionary;
    if ([dic objectForKey:@"CFBundleDisplayName"]) {
        appName = [dic objectForKey:@"CFBundleDisplayName"];
    }
    return appName;
}

+ (NSString*)appVersionWithDots {
    NSString* version = @"1.0.1";
    NSDictionary* dic = [NSBundle mainBundle].infoDictionary;
    if ([dic objectForKey:@"CFBundleShortVersionString"]) {
        version = [dic objectForKey:@"CFBundleShortVersionString"];
    }
    else if ([dic objectForKey:@"CFBundleVersion"]) {
        version = [dic objectForKey:@"CFBundleVersion"];
    }
    
    return version;
}

+ (NSString*)appVersionWithoutDots {
    NSString* version = [FBTools appVersionWithDots];
    
    return [version stringByReplacingOccurrencesOfString:@"." withString:@""];
}

+ (NSInteger)appIntVersion {
    NSInteger version = 101;
    version = [[FBTools appVersionWithoutDots] integerValue];
    return version;
}

+ (float)appFloatVersion {
    //float version = 1.0;
    return [[FBTools appVersionWithoutDots] floatValue];
}




#pragma mark -- runtime encode & decode
+ (void)encodeInstance:(id)instance instanceClass:(Class)instanceClass withCoder:(NSCoder *)encoder {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(instanceClass, &count);
    for (int i=0; i<count; i++) {
        Ivar ivar = ivars[i];
        const char* name = ivar_getName(ivar);
        NSString* key = [NSString stringWithUTF8String:name];
        id value = [instance valueForKey:key];
        [encoder encodeObject:value forKey:key];
    }
    free(ivars);
}
+ (void)decodeInstance:(id)instance instanceClass:(Class)instanceClass withCoder:(NSCoder *)decoder {
    unsigned int count = 0;
    Ivar* ivars = class_copyIvarList(instanceClass, &count);
    for (int i=0; i<count; i++) {
        Ivar ivar = ivars[i];
        const char* name = ivar_getName(ivar);
        NSString* key = [NSString stringWithUTF8String:name];
        id value = [decoder decodeObjectForKey:key];
        [instance setValue:value forKey:key];
    }
    free(ivars);
}





#pragma mark -- video transform
+ (void)transformMovWithAsset:(AVURLAsset*)asset toMP4WithDestPath:(NSString*)destPath completion:(void(^)(NSString *Mp4FilePath, NSError* err))completeBlock {
    
    if (asset == nil) {
        return;
    }
    
    if (destPath == nil || [destPath isEqualToString:@"'"]) {
        return;
    }
    
    NSAssert(asset != nil, @"---------->>>>>>>>>>>> transform err: source asset should not be nil");
    NSAssert(destPath != nil && ![destPath isEqualToString:@""], @"---------->>>>>>>>>>>> transform err: dest path should not be nil");
    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    
    if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetMediumQuality];
        
        exportSession.outputURL = [NSURL fileURLWithPath:destPath];
        exportSession.outputFileType = AVFileTypeMPEG4;
        exportSession.shouldOptimizeForNetworkUse = YES;
        [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
            if (exportSession.status==AVAssetExportSessionStatusCompleted) {
                NSLog(@"------------>>>>>>>>>>>>>> mov to mp4 success, dst: %@", destPath);
                completeBlock(destPath, nil);
            }
            else if (exportSession.status==AVAssetExportSessionStatusFailed||exportSession.status==AVAssetExportSessionStatusCancelled||exportSession.status==AVAssetExportSessionStatusUnknown) {
                
                NSError* err = [NSError errorWithDomain:@"videoTransformError" code:1111 userInfo:nil];
                completeBlock(nil, err);
            }
        }];
    }
}
+ (void)transformMovWithSourceUrl:(NSString *)movFilePath toMP4WithDestPath:(NSString*)destPath completion:(void(^)(NSString *Mp4FilePath, NSError* err))completeBlock {
    if (movFilePath==nil) {
        return;
    }
    
    NSLog(@"------------->>>>>>>>>>>>> begin to transfrom mov %@ to mp4", movFilePath);
    NSURL * url = nil;
    if ([movFilePath hasPrefix:@"assets-library"]) {
        url = [NSURL URLWithString:movFilePath];
    }
    else {
        url = [NSURL fileURLWithPath:movFilePath];
    }
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    [FBTools transformMovWithAsset:avAsset toMP4WithDestPath:destPath completion:completeBlock];
}

+ (void) getVideoThumbnailImage:(NSString *)videoURL completeBlk:(void(^)(UIImage* image))completeBlk {
    if (videoURL==nil) {
        return;
    }
    NSURL * url = nil;
    if ([videoURL hasPrefix:@"assets-library"]) {
        url = [NSURL URLWithString:videoURL];
    }
    else {
        url = [NSURL fileURLWithPath:videoURL];
    }
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
    
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    
    gen.appliesPreferredTrackTransform = YES;//按正确方向对视频进行截图,关键点是将AVAssetImageGrnerator对象的appliesPreferredTrackTransform属性设置为YES。
    
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    
    NSError *error = nil;
    
    CMTime actualTime;
    
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    
    CGImageRelease(image);
    
    completeBlk(thumb);
}







+ (NSString *)getRandomPINString:(NSInteger)length {
    NSMutableString *returnString = [NSMutableString stringWithCapacity:length];
    
    NSString *numbers = @"0123456789";
    
    // First number cannot be 0
    [returnString appendFormat:@"%C", [numbers characterAtIndex:(arc4random() % ([numbers length]-1))+1]];
    
    for (int i = 1; i < length; i++)
    {
        [returnString appendFormat:@"%C", [numbers characterAtIndex:arc4random() % [numbers length]]];
    }
    
    return returnString;
}

+(NSString*)generateRandomString:(NSInteger)length {
    NSMutableString* string = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return string;
}



/**
 *  正则匹配返回符合要求的字符串 数组
 *
 *  @param string   需要匹配的字符串
 *  @param regexStr 正则表达式
 *
 *  @return 符合要求的字符串 数组 (按(),分级,正常0)
 */


+ (NSArray *)matchString:(NSString *)string toRegexString:(NSString *)regexStr {
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSArray * matches = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    
    //match: 所有匹配到的字符,根据() 包含级
    
    NSMutableArray *array = [NSMutableArray array];
    
    for (NSTextCheckingResult *match in matches) {
        
        for (int i = 0; i < [match numberOfRanges]; i++) {
            //以正则中的(),划分成不同的匹配部分
            NSString *component = [string substringWithRange:[match rangeAtIndex:i]];
            
            [array addObject:component];
            
        }
        
    }
    
    return array;
}
@end
