//
//  MainController.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

@class Camera, CameraView, DebugView, Forage, MotionCapture, RouterCable, RouterServer;

@interface MainController : UIViewController {
    
    Camera* camera;
    IBOutlet CameraView* cameraView;
    IBOutlet DebugView* debugView;
    Forage* forage;
    MotionCapture* motionCapture;
    RouterCable* cable;
    RouterServer* server;
    
    int mocapContext;
    NSString* mocapHeading;
    bool mocapMonitor;
    
    NSString* evolvedParameters;
    
    UIView* frontView;
    UIView* backView;
}

- (void)swapView:(UIView*)view;

@end