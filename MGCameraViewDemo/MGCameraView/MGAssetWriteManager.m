//
//  MGAssetWriteManager.m
//  CustomCameraDemo
//
//  Created by mige on 2018/5/8.
//  Copyright © 2018年 mige.com. All rights reserved.
//

#import "MGAssetWriteManager.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface MGAssetWriteManager ()

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterAudioInput;
@property (nonatomic, strong) dispatch_queue_t recordQueue;

@property (nonatomic, assign) BOOL isWriting; //是否正在录制
@property (nonatomic, assign) BOOL isCanWrite; //是否允许写入

@end

@implementation MGAssetWriteManager

- (instancetype)init{
    self = [super init];
    if (self) {
        _recordQueue = dispatch_queue_create("RecordQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)initWithAssetWriteURL:(NSURL *)writeURL outputSize:(CGSize)outputSize{
    self = [super init];
    if (self) {
        _writeURL = writeURL;
        _outputSize = outputSize;
        _recordQueue = dispatch_queue_create("RecordQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc{
    [self restWrite];
}

#pragma mark - public methods
/**
 开始写入
 */
- (void)startWrite{
    NSError *error = [self setupAssetWriter];
    if (error == nil) {
        self.isWriting = YES;
        
    } else {
        [self setupFailDelegate:error];
    }
}

/**
 停止写入
 */
- (void)stopWrite{
    self.isWriting = NO;
    
    __weak __typeof(self)ws = self;
    if(self.assetWriter && self.assetWriter.status == AVAssetWriterStatusWriting){
        [_assetWriter finishWritingWithCompletionHandler:^{
            [ws setupSuccessDelegate:ws.writeURL];
        }];
    }
}

/**
 重置写入
 */
- (void)restWrite{
    self.isCanWrite = NO;
    self.isWriting = NO;
    self.assetWriter = nil;
    self.assetWriterAudioInput = nil;
    self.assetWriterVideoInput = nil;
}

/**
 添加写入资源
 */
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(AVMediaType)mediaType{
    if (sampleBuffer == NULL){
        NSLog(@"Empty sampleBuffer");
        return;
    }
    
    if (self.isWriting == YES){
        //写入数据
        [self assetWriterWithSampleBuffer:sampleBuffer ofMediaType:mediaType];
        
        //设置代理
        [self setupWritingDelegate];
        
    } else {
        return;
    }
}


#pragma mark - private methods
/**
 初始化AssetWriter对象
 */
- (NSError *)setupAssetWriter{
    NSError *error = nil;
    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.writeURL fileType:AVFileTypeMPEG4 error:&error];
    if (error == nil) {
        //写入视频大小
        NSInteger numPixels = self.outputSize.width * self.outputSize.height;
        
        //每像素比特
        CGFloat bitsPerPixel = 6.0;
        NSInteger bitsPerSecond = numPixels * bitsPerPixel;
        
        //码率和帧率设置
        NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                                 AVVideoExpectedSourceFrameRateKey : @(30),
                                                 AVVideoMaxKeyFrameIntervalKey : @(30),
                                                 AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
        
        //视频属性
        NSDictionary *videoCompressionSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                                    AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                                    AVVideoWidthKey : @(self.outputSize.height),
                                                    AVVideoHeightKey : @(self.outputSize.width),
                                                    AVVideoCompressionPropertiesKey : compressionProperties };
        
        //音频设置
        NSDictionary *audioCompressionSettings = @{ AVEncoderBitRatePerChannelKey : @(28000),
                                                    AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                                    AVNumberOfChannelsKey : @(1),
                                                    AVSampleRateKey : @(22050) };
        
        //视频输入
        self.assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
        self.assetWriterVideoInput.expectsMediaDataInRealTime = YES; //必须设为yes，需要从capture session 实时获取数据
        self.assetWriterVideoInput.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
        if ([self.assetWriter canAddInput:self.assetWriterVideoInput]) {
            [self.assetWriter addInput:self.assetWriterVideoInput];
        } else {
            error = [NSError errorWithDomain:@"AssetWriter videoInput append Failed" code:-1 userInfo:nil];
            return error;
        }
        
        //音频输入
        self.assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
        self.assetWriterAudioInput.expectsMediaDataInRealTime = YES; //必须设为yes，需要从capture session 实时获取数据
        if ([self.assetWriter canAddInput:_assetWriterAudioInput]) {
            [self.assetWriter addInput:_assetWriterAudioInput];
        } else {
            error = [NSError errorWithDomain:@"AssetWriter audioInput append Failed" code:-1 userInfo:nil];
            return error;
        }
    }
    return error;
}

/**
 写入数据
 */
- (void)assetWriterWithSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(AVMediaType)mediaType{
    CFRetain(sampleBuffer);
    dispatch_async(self.recordQueue, ^{
        @autoreleasepool {
            @synchronized(self) {
                if (self.isWriting == NO){
                    CFRelease(sampleBuffer);
                    return;
                }
            }
            
            if (self.isCanWrite == NO && mediaType == AVMediaTypeVideo) {
                self.isCanWrite = YES;
                [self.assetWriter startWriting];
                [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
            }
            
            //写入视频数据
            if (mediaType == AVMediaTypeVideo) {
                if (self.assetWriterVideoInput.readyForMoreMediaData == YES) {
                    BOOL success = [self.assetWriterVideoInput appendSampleBuffer:sampleBuffer];
                    if (success == NO) {
                        @synchronized (self) {
                            [self stopWrite];
                            [self restWrite];
                        }
                    }
                }
            }
            
            //写入音频数据
            if (mediaType == AVMediaTypeAudio) {
                if (self.assetWriterAudioInput.readyForMoreMediaData == YES) {
                    BOOL success = [self.assetWriterAudioInput appendSampleBuffer:sampleBuffer];
                    if (success == NO) {
                        @synchronized (self) {
                            [self stopWrite];
                            [self restWrite];
                        }
                    }
                }
            }
            
            CFRelease(sampleBuffer);
        }
    });
}

#pragma mark - 设置代理
/**
 正在写入代理
 */
- (void)setupWritingDelegate{
    if (self.delegate && [self.delegate respondsToSelector:@selector(didAssetWriting:)]) {
        [self.delegate didAssetWriting:self];
    }
}

/**
 成功代理
 */
- (void)setupSuccessDelegate:(NSURL *)writeURL{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(assetWriteManager:didAssetWriteSuccessAtURL:)]) {
            [self.delegate assetWriteManager:self didAssetWriteSuccessAtURL:writeURL];
        }
    });
}

/**
 失败代理
 */
- (void)setupFailDelegate:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(assetWriteManager:didAssetWriteFailWithError:)]) {
            [self.delegate assetWriteManager:self didAssetWriteFailWithError:error];
        }
    });
}

@end
