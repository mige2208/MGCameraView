//
//  MGCameraView.h
//  MGCameraViewDemo
//
//  Created by mige on 2018/5/16.
//  Copyright © 2018年 mige.com. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 视频录制状态
 */
typedef enum{
    MGVideoRecordStateOff = 0x00, //未开启
    MGVideoRecordStatePrepare = 0x01, //准备录制
    MGVideoRecordStateRecording = 0x02, //正在录制
    MGVideoRecordStateFinish = 0x03, //录制结束
    MGVideoRecordStateFail = 0x04, //录制失败
}MGVideoRecordState;

/**
 摄像头位置
 */
typedef enum{
    MGCameraPositionBack = 0x00, //后置摄像头
    MGCameraPositionFront = 0x01, //前置摄像头
}MGCameraPosition;

/**
 闪光灯状态
 */
typedef enum{
    MGCameraFlashStateAuto = 0x00, //自动
    MGCameraFlashStateOn = 0x01, //开启
    MGCameraFlashStateOff = 0x02, //关闭
}MGCameraFlashState;

/**
 相机类型
 */
typedef enum{
    MGCameraTypePhoto = 0x00, //拍照
    MGCameraTypeVideo = 0x01, //录像
}MGCameraType;

@protocol MGCameraViewDelegate;

@interface MGCameraView : UIView

@property (nonatomic, weak) IBOutlet id<MGCameraViewDelegate> delegate;

///相机类型，默认MGCameraTypePhoto
@property (nonatomic, assign) MGCameraType cameraType;

///摄像头位置，默认MGCameraPositionBack
@property (nonatomic, assign) MGCameraPosition cameraPosition;

///闪光灯状态，默认MGCameraFlashStateAuto
@property (nonatomic, assign) MGCameraFlashState flashState;

///录制状态，默认MGVideoRecordStateOff
@property (nonatomic, assign, readonly) MGVideoRecordState recordState;

///是否保存视频到相册，默认NO
@property (nonatomic, assign) BOOL isSaveToPhotoAlbum;

///是否开启人脸追踪，默认NO
@property (nonatomic, assign) BOOL isFacesTrack;

///是否显示人脸识别框，默认YES
@property (nonatomic, assign) BOOL isShowTrackRect;


/**
 开始运行
 */
- (void)startRunning;

/**
 停止运行
 */
- (void)stopRunning;

/**
 切换摄像头
 */
- (void)switchCamera;

/**
 切换闪关灯
 */
- (void)switchFlash;

/**
 开始录制
 */
- (void)startRecordWithSaveURL:(NSURL *)saveURL;

/**
 停止录制
 */
- (void)stopRecord;

/**
 重置录制
 */
- (void)resetRecord;

/**
 拍照
 */
- (void)shutterCameraCompletion:(void (^)(NSError *error, UIImage *image))completedBlock;

@end


@protocol MGCameraViewDelegate <NSObject>

@optional
///正在录制
- (void)didVideoRecording:(MGCameraView *)cameraView;

///录制成功
- (void)cameraView:(MGCameraView *)cameraView didVideoRecordSuccessAtSaveURL:(NSURL *)saveURL;

///录制失败
- (void)cameraView:(MGCameraView *)cameraView didVideoRecordFailWithError:(NSError *)error;

///人脸追踪
- (void)cameraView:(MGCameraView *)cameraView facesTrackWithFaceRects:(NSArray<NSValue *> *)faceRects;

///捕捉图像输出
- (void)cameraView:(MGCameraView *)cameraView captureOutputWithImage:(UIImage *)image;

@end
