//
//  CameraView.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/28/14.
//
//

#import "CameraView.h"
#import "MainController.h"

@implementation CameraView

@synthesize delegate;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [[self layer] setMasksToBounds:YES];
    }
    return self;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if([delegate respondsToSelector:@selector(swapView:)]) {
        [delegate swapView:self];
    }
}

@end
