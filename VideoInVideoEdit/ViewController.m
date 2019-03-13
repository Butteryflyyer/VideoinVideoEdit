//
//  ViewController.m
//  VideoInVideoEdit
//
//  Created by apple on 2019/3/13.
//  Copyright © 2019年 TVM. All rights reserved.
//

#import "ViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
typedef enum {
    LBVideoOrientationUp,               //Device starts recording in Portrait
    LBVideoOrientationDown,             //Device starts recording in Portrait upside down
    LBVideoOrientationLeft,             //Device Landscape Left  (home button on the left side)
    LBVideoOrientationRight,            //Device Landscape Right (home button on the Right side)
    LBVideoOrientationNotFound = 99     //An Error occurred or AVAsset doesn't contains video track
} LBVideoOrientation;
static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};
@interface ViewController ()
{
    AVAsset * videoAsset;
    AVAssetExportSession *exporter;
     CADisplayLink* dlink;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"使用AVFoundation加水印" forState:UIControlStateNormal];
    [button sizeToFit];
    [button addTarget:self action:@selector(useAVFoundation) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.frame = CGRectMake(100, 200, 200, 50);
    // Do any additional setup after loading the view, typically from a nib.
}
-(void)useAVFoundation{
    NSURL *videoPath = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"selfH" ofType:@"MOV"]];
    [self AVsaveVideoPath:videoPath WithWaterImg:[UIImage imageNamed:@"test"] WithCoverImage:[UIImage imageNamed:@"demo.png"] WithQustion:@"文字水印：hudoSngdongBlog" WithFileName:@"waterVideo2"];
}
-(LBVideoOrientation)videoOrientationWithAsset:(AVAsset *)asset
{
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if ([videoTracks count] == 0) {
        return LBVideoOrientationNotFound;
    }
    
    AVAssetTrack* videoTrack    = [videoTracks objectAtIndex:0];
    CGAffineTransform txf       = [videoTrack preferredTransform];
    CGFloat videoAngleInDegree  = RadiansToDegrees(atan2(txf.b, txf.a));
    
    LBVideoOrientation orientation = 0;
    switch ((int)videoAngleInDegree) {
        case 0:
            orientation = LBVideoOrientationRight;
            break;
        case 90:
            orientation = LBVideoOrientationUp;
            break;
        case 180:
            orientation = LBVideoOrientationLeft;
            break;
        case -90:
            orientation     = LBVideoOrientationDown;
            break;
        default:
            orientation = LBVideoOrientationNotFound;
            break;
    }
    
    return orientation;
}
///使用AVfoundation添加水印
- (void)AVsaveVideoPath:(NSURL*)videoPath WithWaterImg:(UIImage*)img WithCoverImage:(UIImage*)coverImg WithQustion:(NSString*)question WithFileName:(NSString*)fileName
{
    if (!videoPath) {
        return;
    }
    
    //1 创建AVAsset实例 AVAsset包含了video的所有信息 self.videoUrl输入视频的路径
    
    //封面图片
    NSDictionary *opts = [NSDictionary dictionaryWithObject:@(YES) forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    videoAsset = [AVURLAsset URLAssetWithURL:videoPath options:opts];     //初始化视频媒体文件
    
    CMTime startTime = CMTimeMakeWithSeconds(0.2, 600);
    CMTime endTime = CMTimeMakeWithSeconds(videoAsset.duration.value/videoAsset.duration.timescale-0.2, videoAsset.duration.timescale);
    
    //声音采集
    AVURLAsset * audioAsset = [[AVURLAsset alloc] initWithURL:videoPath options:opts];
    
    //2 创建AVMutableComposition实例. apple developer 里边的解释 【AVMutableComposition is a mutable subclass of AVComposition you use when you want to create a new composition from existing assets. You can add and remove tracks, and you can add, remove, and scale time ranges.】
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    //3 视频通道  工程文件中的轨道，有音频轨、视频轨等，里面可以插入各种对应的素材
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    //把视频轨道数据加入到可变轨道中 这部分可以做视频裁剪TimeRange
    [videoTrack insertTimeRange:CMTimeRangeFromTimeToTime(startTime, endTime)
                        ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                         atTime:kCMTimeZero error:nil];
    //音频通道
    AVMutableCompositionTrack * audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    //音频采集通道
    AVAssetTrack * audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    [audioTrack insertTimeRange:CMTimeRangeFromTimeToTime(startTime, endTime) ofTrack:audioAssetTrack atTime:kCMTimeZero error:nil];
    
    //3.1 AVMutableVideoCompositionInstruction 视频轨道中的一个视频，可以缩放、旋转等
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = CMTimeRangeFromTimeToTime(kCMTimeZero, videoTrack.timeRange.duration);
    
    // 3.2 AVMutableVideoCompositionLayerInstruction 一个视频轨道，包含了这个轨道上的所有视频素材
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    //    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    BOOL isVideoAssetPortrait_  = NO;
    CGAffineTransform videoTransform = videoAssetTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        //        videoAssetOrientation_ = UIImageOrientationRight;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        //        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetPortrait_ = YES;
    }

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    NSLog(@"%lf   %lf",videoAssetTrack.naturalSize.width,videoAssetTrack.naturalSize.height);
    
    CGSize naturalSize;
    if(isVideoAssetPortrait_){
        naturalSize = CGSizeMake( videoAssetTrack.naturalSize.height,videoAssetTrack.naturalSize.width+500);
    } else {
        naturalSize =  CGSizeMake( videoAssetTrack.naturalSize.width,videoAssetTrack.naturalSize.height+500);;
    }
    
    //    //    naturalSize = videoTrack.naturalSize;
    CGFloat scaleValue = screenSize.height/naturalSize.height;
    scaleValue = 1;
    //    CGSize scaleSize = CGSizeMake(naturalSize.width * scaleValue, naturalSize.height * scaleValue);
    //    CGPoint topLeft = CGPointMake(100, 100);
    //
    CGAffineTransform originTransform = videoTrack.preferredTransform;
    ////
    //    naturalSize = CGSizeMake(videoAssetTrack.naturalSize.height,videoAssetTrack.naturalSize.width+500);
    //    CGAffineTransform resultTransform = CGAffineTransformConcat(CGAffineTransformScale(originTransform, scaleValue, scaleValue), CGAffineTransformMakeTranslation(topLeft.x, topLeft.y));
    ////      CGAffineTransform resultTransform = CGAffineTransformConcat(CGAffineTransformScale(originTransform, scaleValue, scaleValue),CGAffineTransformRotate(originTransform, M_PI_2));
    //    [videolayerInstruction setTransform:resultTransform atTime:kCMTimeZero];
    //
    [videolayerInstruction setOpacity:0.0 atTime:endTime];
    
    
    LBVideoOrientation  videoOrientation = [self videoOrientationWithAsset:videoAsset];
    
    CGAffineTransform t1 = CGAffineTransformIdentity;
    CGAffineTransform t2 = CGAffineTransformIdentity;
    CGAffineTransform t3 = CGAffineTransformIdentity;
    NSLog(@" --- 视频转向 -- %ld",(long)videoOrientation);
    switch (videoOrientation)
    {
        case LBVideoOrientationUp:
            
            t1 = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height - 0, 0 - 0);
            //            t1 = CGAffineTransformScale(originTransform, scaleValue, scaleValue);
            t2 = CGAffineTransformRotate(t1, M_PI_2);
            t3 = CGAffineTransformScale(t2, scaleValue, scaleValue);
            break;
        case LBVideoOrientationDown:
            t1 = CGAffineTransformMakeTranslation(
                                                  0 - 0,
                                                  videoTrack.naturalSize.width - 0);  // not fixed width is the real height in upside down
            t2 = CGAffineTransformRotate(t1, -M_PI_2);
            t3 = CGAffineTransformScale(t2, scaleValue, scaleValue);
            break;
        case  LBVideoOrientationRight:
            t1 = CGAffineTransformMakeTranslation(0 - 0, 0 - 0);
            t2 = CGAffineTransformRotate(t1, 0);
            t3 = CGAffineTransformScale(t2, scaleValue, scaleValue);
            break;
        case LBVideoOrientationLeft:
            t1 = CGAffineTransformMakeTranslation(videoTrack.naturalSize.width - 0,
                                                  videoTrack.naturalSize.height - 0);
            t2 = CGAffineTransformRotate(t1, M_PI);
            t3 = CGAffineTransformScale(t2, scaleValue, scaleValue);
            break;
        default:
            NSLog(@"【该视频未发现设置支持的转向】");
            break;
    }
    
    CGAffineTransform finalTransform = t3;
    [videolayerInstruction setTransform:t3 atTime:kCMTimeZero];
    
    //    [videolayerInstruction setCropRectangle:CGRectMake(0, 0, 100, 100) atTime:CMTimeMake(1, 1)];
    
    // 3.3 - Add instructions
    mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction,nil];
    //AVMutableVideoComposition：管理所有视频轨道，可以决定最终视频的尺寸，裁剪需要在这里进行
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    
    
    
    float renderWidth, renderHeight;
    renderWidth = naturalSize.width;
    renderHeight = naturalSize.height;
    //    renderWidth = 1000;
    //    renderHeight = 2000;
    
    NSLog(@"%lf,%lf",renderWidth,renderHeight);
    NSLog(@"%lf,%lf",[UIScreen mainScreen].bounds.size.width,[UIScreen mainScreen].bounds.size.height);
    
    
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
    mainCompositionInst.frameDuration = CMTimeMake(1, 25);
    [self applyVideoEffectsToComposition:mainCompositionInst WithWaterImg:img WithCoverImage:coverImg WithQustion:question size:CGSizeMake(renderWidth, renderHeight)];
    //    mainCompositionInst.customVideoCompositorClass = [CustomVideoCompositor class];
    
    // 4 - 输出路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4",fileName]];
    unlink([myPathDocs UTF8String]);
    NSURL* videoUrl = [NSURL fileURLWithPath:myPathDocs];
    
    dlink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgress)];
    [dlink setFrameInterval:15];
    [dlink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [dlink setPaused:NO];
    // 5 - 视频文件输出
    
    exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=videoUrl;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.videoComposition = mainCompositionInst;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            //这里是输出视频之后的操作，做你想做的
            [self exportDidFinish:exporter];
        });
    }];
    
}

- (void)exportDidFinish:(AVAssetExportSession*)session {
    if (session.status == AVAssetExportSessionStatusCompleted) {
        NSURL *outputURL = session.outputURL;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __block PHObjectPlaceholder *placeholder;
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path)) {
                NSError *error;
                [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
                    PHAssetChangeRequest* createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outputURL];
                    placeholder = [createAssetRequest placeholderForCreatedAsset];
                } error:&error];
                if (error) {
                    [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"%@",error]];
                }
                else{
                    [SVProgressHUD showSuccessWithStatus:@"视频已经保存到相册"];
                }
            }else {
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"视频保存相册失败，请设置软件读取相册权限", nil)];
            }
        });
    }
}

- (void)applyVideoEffectsToComposition:(AVMutableVideoComposition *)composition WithWaterImg:(UIImage*)img WithCoverImage:(UIImage*)coverImg WithQustion:(NSString*)question  size:(CGSize)size {

    //水印
    CALayer *imgLayer = [CALayer layer];
    imgLayer.contents = (id)img.CGImage;
    //    imgLayer.bounds = CGRectMake(0, 0, size.width, size.height);
    //    imgLayer.bounds = CGRectMake(0, 700, 1000, 600);
    
    imgLayer.frame  = CGRectMake(0, 0, size.width, 500);
    //    imgLayer.position = CGPointMake(size.width/2.0, size.height/2.0);
    

    // 2 - The usual overlay
    CALayer *overlayLayer = [CALayer layer];

    [overlayLayer addSublayer:imgLayer];
    overlayLayer.frame = CGRectMake(0, 0,size.width, size.height);
    [overlayLayer setMasksToBounds:YES];
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:overlayLayer];

    

    composition.animationTool = [AVVideoCompositionCoreAnimationTool
                                 videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
}

//更新生成进度
- (void)updateProgress {
    [SVProgressHUD showProgress:exporter.progress status:NSLocalizedString(@"生成中...", nil)];
    if (exporter.progress>=1.0) {
        [dlink setPaused:true];
        [dlink invalidate];
        //        [SVProgressHUD dismiss];
    }
}


@end
