//
//  Camera.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/15/14.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class Camera, CameraView;
@protocol CameraPipeline;

@protocol CameraPipelineDelegate
- (void)pipeline:(id<CameraPipeline>)pipeline didProcessFrame:(id)result;
@end

@protocol CameraPipeline
- (void)didReceiveFrame:(CMSampleBufferRef)frame fromCamera:(Camera*)camera;
@property AVCaptureDevicePosition devicePosition;
@property NSString* quality;
@property id<NSObject, CameraPipelineDelegate> delegate;
@end

@interface Camera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureSession* session;
    AVCaptureVideoDataOutput* output;
    dispatch_queue_t queue;
}

- (void)startPipeline:(id<CameraPipeline>)pipeline;
- (void)stop;

@property id<CameraPipeline> pipeline;
@property CameraView* view;
@property AVCaptureVideoPreviewLayer* previewLayer;

@end
