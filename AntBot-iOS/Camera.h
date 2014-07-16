//
//  Camera.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/15/14.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol CameraPipelineDelegate
- (void)didProcessFrame:(id)result;
@end

@protocol CameraPipeline
- (void)didReceiveFrame:(CMSampleBufferRef)frame;
@property AVCaptureDevicePosition devicePosition;
@optional @property NSString* quality;
@end

@interface Camera : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureSession* session;
    AVCaptureVideoDataOutput* output;
    AVCaptureVideoPreviewLayer* previewLayer;
}

- (void)startPipeline:(id<CameraPipeline>)pipeline;
- (void)stop;

@property id<CameraPipeline> pipeline;

@end
