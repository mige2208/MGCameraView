//
//  MGAssetWriteManager.h
//  CustomCameraDemo
//
//  Created by mige on 2018/5/8.
//  Copyright © 2018年 mige.com. All rights reserved.
//
/**
 资源写入管理
 */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol MGAssetWriteManagerDelegate;
@interface MGAssetWriteManager : NSObject

@property (nonatomic, weak) id<MGAssetWriteManagerDelegate> delegate;

@property (nonatomic, strong) NSURL *writeURL; //视频写入URL
@property (nonatomic, assign) CGSize outputSize; //写入视频大小

/**
 初始化

 @param writeURL 资源写入路径
 @param outputSize 写入视频的尺寸
 */
- (instancetype)initWithAssetWriteURL:(NSURL *)writeURL outputSize:(CGSize)outputSize;

/**
 开始写入
 */
- (void)startWrite;

/**
 停止写入
 */
- (void)stopWrite;

/**
 重置写入
 */
- (void)restWrite;

/**
 添加写入资源
 
 @param sampleBuffer 资源缓存
 @param mediaType 媒体类型
 */
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(AVMediaType)mediaType;

@end

@protocol MGAssetWriteManagerDelegate <NSObject>

@optional
- (void)didAssetWriting:(MGAssetWriteManager *)manager;

- (void)assetWriteManager:(MGAssetWriteManager *)manager didAssetWriteSuccessAtURL:(NSURL *)writeURL;

- (void)assetWriteManager:(MGAssetWriteManager *)manager didAssetWriteFailWithError:(NSError *)error;

@end
