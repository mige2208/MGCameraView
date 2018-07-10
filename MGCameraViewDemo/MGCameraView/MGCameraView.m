//
//  MGCameraView.m
//  MGCameraViewDemo
//
//  Created by mige on 2018/5/16.
//  Copyright © 2018年 mige.com. All rights reserved.
//

#import "MGCameraView.h"
#import <AVFoundation/AVFoundation.h>
#import "MGAssetWriteManager.h"

#ifdef NSFoundationVersionNumber_iOS_9_x_Max
#import <Photos/Photos.h>
#else
#import <AssetsLibrary/AssetsLibrary.h>
#endif

@interface MGCameraView () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, MGAssetWriteManagerDelegate>

//捕获设备，通常是前置摄像头，后置摄像头，麦克风
@property (nonatomic, strong) AVCaptureDevice *videoDevice;
@property (nonatomic, strong) AVCaptureDevice *audioDevice;

//输入设备
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;

//输出内容
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong) AVCaptureStillImageOutput *imageOutPut;

//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property (nonatomic, strong) AVCaptureSession *session;

//图像预览层，实时显示捕获的图像
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

//队列
@property (nonatomic, strong) dispatch_queue_t recordQueue;

//资源写入管理器
@property (nonatomic, strong) MGAssetWriteManager *writeManager;

//人脸识别
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;

@end


@implementation MGCameraView{
    UIView *m_highlitView[50];
}

#pragma mark - override
- (void)layoutSubviews{
    [super layoutSubviews];
    if (self.previewLayer != nil) {
        self.previewLayer.frame = self.bounds;
    }
}

- (void)awakeFromNib{
    [super awakeFromNib];
    [self setupView];
}

- (instancetype)init{
    self = [super init];
    if (self) {
        [self setupView];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

#pragma mark - getter && setter
- (dispatch_queue_t)recordQueue{
    if (_recordQueue == nil) {
        _recordQueue = dispatch_queue_create("RecordQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _recordQueue;
}

- (MGAssetWriteManager *)writeManager{
    if (_writeManager == nil) {
        _writeManager = [[MGAssetWriteManager alloc] init];
        _writeManager.delegate = self;
    }
    return _writeManager;
}

- (void)setCameraType:(MGCameraType)cameraType{
    [self switchCameraType:cameraType];
    [self setupImageOutPut];
}

- (void)setCameraPosition:(MGCameraPosition)cameraPosition{
    [self switchCamera:cameraPosition];
}

- (void)setFlashState:(MGCameraFlashState)flashState{
    [self switchFlash:flashState];
}

- (void)setIsFacesTrack:(BOOL)isFacesTrack{
    _isFacesTrack = isFacesTrack;
    [self setupFaceMetadataOutPut];
}

#pragma mark - 初始化
/**
 设置视图
 */
- (void)setupView{
    //初始化配置
    [self initConfig];
    
    //监听离开、回到程序
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    //开始捕获
    [self startCapture];
}

/**
 初始化配置
 */
- (void)initConfig{
    _cameraType = MGCameraTypePhoto;
    _recordState = MGVideoRecordStateOff;
    _cameraPosition = MGCameraPositionBack;
    _flashState = MGCameraFlashStateAuto;
    _isSaveToPhotoAlbum = NO;
    _isFacesTrack = NO;
    _isShowTrackRect = YES;
}

/**
 开始捕获
 */
- (void)startCapture{
    //初始化会话
    [self setupCaptureSession];
    
    //设置视频的输入输出
    [self setupVideoCapture];
    
    //设置音频的输入输出
    if (_cameraType == MGCameraTypeVideo) {
        [self setupAudioCapture];
    }
    
    //设置预览层
    [self setupPreviewLayer];
    
    //开始运行
    [self startRunning];
}

/**
 初始化会话
 */
- (void)setupCaptureSession{
    _session = [[AVCaptureSession alloc] init];
    if ([_session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        _session.sessionPreset = AVCaptureSessionPresetHigh;
    }
}

#pragma mark - 视频采集
/**
 设置视频的输入输出
 */
- (void)setupVideoCapture{
    //视频输入
    [self setupVideoInput];
    
    //视频输出
    [self setupVideoOutPut];
    
    //图片输出
    [self setupImageOutPut];
    
    //人脸识别
    [self setupFaceMetadataOutPut];
}

/**
 设置视频输入
 */
- (void)setupVideoInput{
    AVCaptureDevicePosition position = AVCaptureDevicePositionUnspecified;
    if (self.cameraPosition == MGCameraPositionBack) {
        position = AVCaptureDevicePositionBack;
    } else if (self.cameraPosition == MGCameraPositionFront) {
        position = AVCaptureDevicePositionFront;
    }
    
    //初始化设备，默认前置摄像头
    self.videoDevice = [self getCameraDeviceWithPosition:position];
    
    //使用设备初始化输入
    if (self.videoDevice != nil) {
        NSError *error = nil;
        self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.videoDevice error:&error];
        if ([self.session canAddInput:self.videoInput]) {
            [self.session addInput:self.videoInput];
        }
    }
}

/**
 设置视频输出
 */
- (void)setupVideoOutPut{
    //生成输出对象
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;//丢弃延迟的帧
    [self.videoOutput setSampleBufferDelegate:self queue:self.recordQueue];
    
    //指定像素的输出格式，这个参数直接影响到生成图像的成功与否
    NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber *value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [self.videoOutput setVideoSettings:videoSettings];
    
    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
    }
}

/**
 设置图片输出
 */
- (void)setupImageOutPut{
    if (self.cameraType == MGCameraTypePhoto) {
        self.imageOutPut = [[AVCaptureStillImageOutput alloc] init];
        if ([self.session canAddOutput:self.imageOutPut]) {
            [self.session addOutput:self.imageOutPut];
        }
    } else {
        [self.session removeOutput:self.imageOutPut];
        self.imageOutPut = nil;
    }
}

/**
 设置人脸识别输出
 */
- (void)setupFaceMetadataOutPut{
    if (self.isFacesTrack == YES) {
        self.metadataOutput = [[AVCaptureMetadataOutput alloc] init];
        [self.metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        
        if ([self.session canAddOutput:self.metadataOutput]) {
            [self.session addOutput:self.metadataOutput];
            self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
        }
    } else {
        [self.session removeOutput:self.metadataOutput];
        self.metadataOutput = nil;
    }
}

/**
 获取摄像头
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position{
    AVCaptureDevice *camera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices){
        if (device.position == position) {
            camera = device;
            break;
        }
    }
    return camera;
}

#pragma mark - 音频采集
/**
 设置音频的输入输出
 */
- (void)setupAudioCapture{
    //视频输入
    [self setupAudioInput];
    
    //视频输出
    [self setupAudioOutPut];
}

/**
 设置音频输入
 */
- (void)setupAudioInput{
    //初始化设备
    self.audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    //使用设备初始化输入
    if (self.audioDevice != nil) {
        NSError *error = nil;
        self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:&error];
        if ([self.session canAddInput:self.audioInput]) {
            [self.session addInput:self.audioInput];
        }
    }
}

/**
 设置音频输出
 */
- (void)setupAudioOutPut{
    //生成输出对象
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self queue:self.recordQueue];
    
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
}

/**
 移除音频
 */
- (void)removeAudioCapture{
    [self.session removeInput:self.audioInput];
    [self.session removeOutput:self.audioOutput];
    self.audioDevice = nil;
    self.audioInput = nil;
    self.audioOutput = nil;
}

#pragma mark - 预览层
/**
 设置预览层
 session负责驱动input进行信息的采集，layer负责把图像渲染显示
 */
- (void)setupPreviewLayer{
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:self.previewLayer];
}

/**
 调整预览层方向
 */
- (void)fixPreviewLayerOrientation{
    dispatch_async(dispatch_get_main_queue(), ^{
        CGAffineTransform transform;
        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        if (orientation == UIDeviceOrientationPortrait) {
            transform = CGAffineTransformMakeRotation(0.0);
            
        } else if (orientation == UIDeviceOrientationLandscapeRight) {
            transform = CGAffineTransformMakeRotation(M_PI/2.0);
            
        } else if (orientation == UIDeviceOrientationLandscapeLeft) {
            transform = CGAffineTransformMakeRotation(-M_PI/2.0);
            
        } else if (orientation == UIDeviceOrientationPortraitUpsideDown) {
            transform = CGAffineTransformMakeRotation(-M_PI);
            
        } else {
            transform = CGAffineTransformMakeRotation(0.0);
        }
        
        self.previewLayer.affineTransform = transform;
    });
}

#pragma mark - 开始 & 停止
/**
 开始运行
 */
- (void)startRunning{
    if (self.session.isRunning == NO) {
        [self.session startRunning];
    }
}

/**
 停止运行
 */
- (void)stopRunning{
    if (self.session.isRunning == YES) {
        [self.session stopRunning];
    }
}

#pragma mark - 视频录制
/**
 开始录制
 */
- (void)startRecordWithSaveURL:(NSURL *)saveURL{
    if (self.recordState == MGVideoRecordStateRecording) {
        return;
    }
    
    if (saveURL != nil) {
        _recordState = MGVideoRecordStatePrepare;
        self.writeManager.writeURL = saveURL;
        self.writeManager.outputSize = self.frame.size;
        [self.writeManager startWrite];
        
    } else {
        _recordState = MGVideoRecordStateFail;
        NSError *error = [NSError errorWithDomain:@"视频保存路径不能为空" code:-1 userInfo:nil];
        if (self.delegate && [self.delegate respondsToSelector:@selector(cameraView:didVideoRecordFailWithError:)]) {
            [self.delegate cameraView:self didVideoRecordFailWithError:error];
        }
    }
}

/**
 停止录制
 */
- (void)stopRecord{
    _recordState = MGVideoRecordStateFinish;
    [self.writeManager stopWrite];
}

/**
 重置录制
 */
- (void)resetRecord{
    _recordState = MGVideoRecordStateOff;
    [self.writeManager restWrite];
}

/**
 视频录制
 */
- (void)recordWithOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    @synchronized(self) {
        if (self.recordState == MGVideoRecordStatePrepare) {
            _recordState = MGVideoRecordStateRecording;
        }
    }
    
    //防止出现黑屏
    if (self.recordState != MGVideoRecordStateRecording) {
        return;
    }
    
    //视频
    if (connection == [self.videoOutput connectionWithMediaType:AVMediaTypeVideo]) {
        @synchronized(self) {
            [self.writeManager appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
        }
    }
    
    //音频
    if (connection == [self.audioOutput connectionWithMediaType:AVMediaTypeAudio]) {
        @synchronized(self) {
            [self.writeManager appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeAudio];
        }
    }
}

/**
 保存视频到系统相册
 */
- (void)saveVideoAtURL:(NSURL *)url completionBlock:(void (^)(NSError *error))completedBlock{
#ifdef NSFoundationVersionNumber_iOS_9_x_Max
    // iOS 9.0 及以后的版本
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (completedBlock) {
            completedBlock(error);
        }
    }];
#else
    // iOS 9.0 之前
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    [lib writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error) {
        if (completedBlock) {
            completedBlock(error);
        }
    }];
#endif
}

#pragma mark - 切换相机类型
/**
 切换相机类型
 */
- (void)switchCameraType:(MGCameraType)cameraType{
    _cameraType = cameraType;
    if (_cameraType == MGCameraTypePhoto) {
        [self removeAudioCapture];
        
    } else if (_cameraType == MGCameraTypeVideo) {
        if (self.audioInput == nil && self.audioOutput == nil) {
            [self setupAudioCapture];
        }
    }
}

#pragma mark - 切换摄像头
/**
 切换摄像头
 */
- (void)switchCamera{
    //获取当前需要展示的摄像头
    AVCaptureDevicePosition position = self.videoInput.device.position;
    if (position == AVCaptureDevicePositionBack) {
        [self switchCamera:MGCameraPositionFront];
    } else {
        [self switchCamera:MGCameraPositionBack];
    }
}

/**
 切换摄像头
 */
- (void)switchCamera:(MGCameraPosition)position{
    _cameraPosition = position;
    if (position == MGCameraPositionFront) {
        [self switchCameraWithPosition:AVCaptureDevicePositionFront];
        
    } else if (position == MGCameraPositionBack) {
        
        [self switchCameraWithPosition:AVCaptureDevicePositionBack];
    }
}

/**
 切换摄像头模式
 */
- (void)switchCameraWithPosition:(AVCaptureDevicePosition)position{
    [self.session stopRunning];
    
    //根据当前摄像头，设置新的视频输入
    self.videoDevice = [self getCameraDeviceWithPosition:position];
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:nil];
    
    //切换session的视频输入
    [self.session beginConfiguration];
    [self.session removeInput:self.videoInput];
    [self.session addInput:newInput];
    [self.session commitConfiguration];
    self.videoInput = newInput;
    
    [self.session startRunning];
}

#pragma mark - 切换闪关灯
/**
 切换闪关灯
 */
- (void)switchFlash{
    AVCaptureTorchMode torchMode = self.videoInput.device.torchMode;
    if (torchMode == AVCaptureTorchModeOff) {
        [self switchFlash:MGCameraFlashStateOn];
        
    } else if (torchMode == AVCaptureTorchModeOn) {
        [self switchFlash:MGCameraFlashStateAuto];
        
    } else if (torchMode == AVCaptureTorchModeAuto) {
        [self switchFlash:MGCameraFlashStateOff];
    };
}

/**
 切换闪关灯
 */
- (void)switchFlash:(MGCameraFlashState)flashState{
    _flashState = flashState;
    switch (flashState) {
        case MGCameraFlashStateAuto:
            [self switchFlashWithCaptureTorchMode:AVCaptureTorchModeAuto];
            break;
            
        case MGCameraFlashStateOn:
            [self switchFlashWithCaptureTorchMode:AVCaptureTorchModeOn];
            break;
            
        case MGCameraFlashStateOff:
            [self switchFlashWithCaptureTorchMode:AVCaptureTorchModeOff];
            break;
            
        default:
            break;
    }
}

/**
 切换闪关灯模式
 */
- (void)switchFlashWithCaptureTorchMode:(AVCaptureTorchMode)torchMode{
    if ([self.videoInput.device hasTorch]) {
        [self.videoInput.device lockForConfiguration:nil];
        [self.videoInput.device setTorchMode:torchMode];
        [self.videoInput.device unlockForConfiguration];
    }
}

#pragma mark - 拍照
/**
 拍照
 */
- (void)shutterCameraCompletion:(void (^)(NSError *error, UIImage *image))completedBlock{
    AVCaptureConnection *videoConnection = [self.imageOutPut connectionWithMediaType:AVMediaTypeVideo];
    if (videoConnection == nil) {
        if (completedBlock) {
            NSError *error = [NSError errorWithDomain:@"connection video fail" code:-1 userInfo:nil];
            completedBlock(error, nil);
        }
        return;
    }
    
    [self.imageOutPut captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer == NULL) {
            return;
        }
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [UIImage imageWithData:imageData];
        if (completedBlock) {
            completedBlock(error, image);
        }
    }];
}

#pragma mark - 人脸追踪
/**
 人脸追踪
 */
- (void)facesTrackWithMetadataObjects:(NSArray<AVMetadataObject *> *)metadataObjects{
    NSMutableArray *bounsArr = [NSMutableArray array];
    for (AVMetadataFaceObject *faceObject in metadataObjects) {
        CGRect faceRect = [self.previewLayer rectForMetadataOutputRectOfInterest:faceObject.bounds];
        NSValue *bouns = [NSValue valueWithCGRect:faceRect];
        [bounsArr addObject:bouns];
    }
    
    //设置代理
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(cameraView:facesTrackWithFaceRects:)]) {
            [self.delegate cameraView:self facesTrackWithFaceRects:bounsArr];
        }
    });
    
    //显示人脸识别框
    if (self.isShowTrackRect == YES) {
        [self addTrackRectWithRects:bounsArr];
    }
}

/**
 添加识别区域框
 */
-(void)addTrackRectWithRects:(NSArray *)rects{
    for (int i = 0; m_highlitView[i] != nil; i++) {
        m_highlitView[i].hidden = YES;
    }
    
    for (NSInteger i = 0; i < rects.count; i++) {
        CGRect rect = [rects[i] CGRectValue];
        if (m_highlitView[i] == nil) {
            m_highlitView[i] = [[UIView alloc] initWithFrame:rect];
            m_highlitView[i].layer.cornerRadius = 5.0;
            m_highlitView[i].layer.borderWidth = 1.0;
            m_highlitView[i].layer.borderColor = [[UIColor yellowColor] CGColor];
            [self addSubview:m_highlitView[i]];
            
        } else {
            m_highlitView[i].hidden = NO;
            m_highlitView[i].frame = rect;
        }
    }
}

#pragma mark - 捕捉图像
/**
 捕捉图像
 */
- (void)captureOutputImageWithSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    if (self.delegate && [self.delegate respondsToSelector:@selector(cameraView:captureOutputWithImage:)]) {
        //图像捕捉
        UIImage *image = [self imageWithOutputSampleBuffer:sampleBuffer];
        image = [self fixImageOrientation:image];
        
        //设置代理
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate cameraView:self captureOutputWithImage:image];
        });
    }
}

/**
 捕捉图像
 */
- (UIImage *)imageWithOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    UIImageOrientation imageOrientation = UIImageOrientationRight;
    if (self.cameraPosition == MGCameraPositionFront) {
        imageOrientation = UIImageOrientationLeftMirrored;
    }
    UIImage *image = [UIImage imageWithCGImage:newImage scale:1 orientation:imageOrientation];
    
    CGImageRelease(newImage);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    return image;
}

/**
 调整图片方向
 */
- (UIImage *)fixImageOrientation:(UIImage *)image{
    
    UIImageOrientation imageOrientation = image.imageOrientation;
    CGFloat imgWidth = image.size.width;
    CGFloat imgHeight = image.size.height;
    
    // No-op if the orientation is already correct
    if (imageOrientation == UIImageOrientationUp) return image;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, imgWidth, imgHeight);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, imgWidth, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, imgHeight);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, imgWidth, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, imgHeight, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, imgWidth, imgHeight,
                                             CGImageGetBitsPerComponent(image.CGImage), 0,
                                             CGImageGetColorSpace(image.CGImage),
                                             CGImageGetBitmapInfo(image.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,imgHeight,imgWidth), image.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,imgWidth,imgHeight), image.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [[UIImage alloc]initWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    //调整预览层方向
    [self fixPreviewLayerOrientation];
    
    //视频录制
    [self recordWithOutputSampleBuffer:sampleBuffer fromConnection:connection];
    
    //捕捉图像
    [self captureOutputImageWithSampleBuffer:sampleBuffer];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    //人脸追踪
    [self facesTrackWithMetadataObjects:metadataObjects];
}

#pragma mark - MGAssetWriteManagerDelegate
- (void)didAssetWriting:(MGAssetWriteManager *)manager{
    if (self.delegate && [self.delegate respondsToSelector:@selector(didVideoRecording:)]) {
        [self.delegate didVideoRecording:self];
    }
}

- (void)assetWriteManager:(MGAssetWriteManager *)manager didAssetWriteSuccessAtURL:(NSURL *)writeURL{
    //保存到相册
    if (self.isSaveToPhotoAlbum == YES) {
        [self saveVideoAtURL:writeURL completionBlock:nil];
    }
    
    //成功代理
    if (self.delegate && [self.delegate respondsToSelector:@selector(cameraView:didVideoRecordSuccessAtSaveURL:)]) {
        [self.delegate cameraView:self didVideoRecordSuccessAtSaveURL:writeURL];
    }
}

- (void)assetWriteManager:(MGAssetWriteManager *)manager didAssetWriteFailWithError:(NSError *)error{
    _recordState = MGVideoRecordStateFail;
    if (self.delegate && [self.delegate respondsToSelector:@selector(cameraView:didVideoRecordFailWithError:)]) {
        [self.delegate cameraView:self didVideoRecordFailWithError:error];
    }
}

#pragma mark - Notification
/**
 进入后台
 */
- (void)enterBackground:(NSNotification *)notify{
    [self stopRecord];
    [self.session stopRunning];
}

/**
 进入前台
 */
- (void)enterForeground:(NSNotification *)notify{
    [self resetRecord];
    [self.session startRunning];
}


@end
