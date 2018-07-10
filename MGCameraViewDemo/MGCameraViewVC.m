//
//  MGCameraViewVC.m
//  MGCameraViewDemo
//
//  Created by mige on 2018/5/16.
//  Copyright © 2018年 mige.com. All rights reserved.
//

#import "MGCameraViewVC.h"
#import "MGCameraView.h"

@interface MGCameraViewVC () <MGCameraViewDelegate>

@property (weak, nonatomic) IBOutlet MGCameraView *cameraView;
@property (weak, nonatomic) IBOutlet UIButton *actionBtn;
@property (weak, nonatomic) IBOutlet UIButton *flashBtn;
@property (weak, nonatomic) IBOutlet UIButton *cameraBtn;
@property (weak, nonatomic) IBOutlet UIImageView *previewImgView;

@end

@implementation MGCameraViewVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.actionBtn.tag = 100;
    self.cameraView.cameraType = MGCameraTypePhoto;
    self.cameraView.isSaveToPhotoAlbum = YES;
    self.cameraView.isFacesTrack = YES;
    self.cameraView.cameraPosition = MGCameraPositionBack;
    self.cameraView.delegate = self;
}


- (IBAction)onFlashAction:(id)sender {
    [self.cameraView switchFlash];
    if (self.cameraView.flashState == MGCameraFlashStateAuto) {
        [self.flashBtn setTitle:@"闪光灯（自动）" forState:UIControlStateNormal];
    } else if (self.cameraView.flashState == MGCameraFlashStateOn) {
        [self.flashBtn setTitle:@"闪光灯（打开）" forState:UIControlStateNormal];
    } else if (self.cameraView.flashState == MGCameraFlashStateOff) {
        [self.flashBtn setTitle:@"闪光灯（关闭）" forState:UIControlStateNormal];
    }
}

- (IBAction)onCameraSwitchAction:(id)sender {
    [self.cameraView switchCamera];
}

- (IBAction)onButtonAction:(id)sender {
    if (self.actionBtn.tag == 100) {
        self.actionBtn.tag = 200;
        [self.cameraView startRecordWithSaveURL:[self generateVideoWriteURL]];
        [self.actionBtn setTitle:@"正在录制" forState:UIControlStateNormal];
    } else {
        self.actionBtn.tag = 100;
        [self.cameraView stopRecord];
        [self.actionBtn setTitle:@"录制完成" forState:UIControlStateNormal];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.actionBtn setTitle:@"开始录制" forState:UIControlStateNormal];
            [self.cameraView resetRecord];
        });
    }
}

/**
 获取视频保存路径
 */
- (NSURL *)generateVideoWriteURL{
    NSString *folderPath = [self getVideoDocumentPath];
    NSString *fileName = [NSUUID UUID].UUIDString;
    NSString *path = [NSString stringWithFormat:@"%@/%@.mp4", folderPath, fileName];
    NSURL *url = [NSURL fileURLWithPath:path];
    return url;
}

/**
 获取视频文件夹
 */
- (NSString *)getVideoDocumentPath{
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *folderPath = [NSString stringWithFormat:@"%@/%@", docPath, @"Video"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:folderPath] == NO) {
        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return folderPath;
}

#pragma mark - MGCameraViewDelegate
//正在录制
- (void)didVideoRecording:(MGCameraView *)cameraView{
    
}

//录制成功
- (void)cameraView:(MGCameraView *)cameraView didVideoRecordSuccessAtSaveURL:(NSURL *)saveURL{
    NSLog(@"---->>>Success %@", saveURL);
}

//录制失败
- (void)cameraView:(MGCameraView *)cameraView didVideoRecordFailWithError:(NSError *)error{
    NSLog(@"---->>>Fail %@", error.domain);
}

//人脸追踪
- (void)cameraView:(MGCameraView *)cameraView facesTrackWithFaceRects:(NSArray<NSValue *> *)faceRects{
    
}

//捕捉图像输出
- (void)cameraView:(MGCameraView *)cameraView captureOutputWithImage:(UIImage *)image{
    self.previewImgView.image = image;
}

@end
