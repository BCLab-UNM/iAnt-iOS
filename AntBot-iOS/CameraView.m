//
//  CameraView.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/28/14.
//
//

#import "CameraView.h"

@implementation CameraView

@synthesize previewLayer;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [[self layer] setMasksToBounds:YES];
    }
    return self;
}

- (void)setPreviewLayer:(AVCaptureVideoPreviewLayer*)_previewLayer {
    previewLayer = _previewLayer;
    CALayer* layer = [self layer];
    [layer addSublayer:previewLayer];
    [previewLayer setFrame:[layer frame]];
}

@end
