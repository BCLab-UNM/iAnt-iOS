//
//  CameraView.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/28/14.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraView : UIView

@property (nonatomic) AVCaptureVideoPreviewLayer* previewLayer;
@property id delegate;

@end
