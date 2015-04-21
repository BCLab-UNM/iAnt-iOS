#import "MainController.h"

#import "Camera.h"
#import "CameraView.h"
#import "DebugView.h"
#import "Forage.h"
#import "LocalizationPipeline.h"
#import "MotionCapture.h"
#import "RouterServer.h"
#import "RouterCable.h"
#import "Utilities.h"

#import <math.h>

@implementation MainController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [cameraView setDelegate:self];
    [debugView setDelegate:self];
    
    // Camera
    camera = [[Camera alloc] init];
    [camera setView:cameraView];
    
    // Communication
    server = [[RouterServer alloc] init];
    cable = [[RouterCable alloc] init];
    
    // Logic
    //motionCapture = [[MotionCapture alloc] initWithCable:cable server:server];
    forage = [[Forage alloc] initWithCable:cable server:server camera:camera];
    
    [forage setDebug:debugView];
    [debugView setForage:forage];
}

- (void)viewDidUnload {
    [[forage cable] send:@"motors,0,0,0"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)swapView:(UIView*)view {
    UIView* newView = (view == cameraView) ? debugView : cameraView;
    UIViewAnimationOptions transition = (view == cameraView) ? UIViewAnimationOptionTransitionCurlDown : UIViewAnimationOptionTransitionCurlUp;
    [UIView transitionFromView:view toView:newView duration:.35f options:transition completion:^(BOOL finished){}];
}

@end
