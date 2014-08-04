//
//  MainController.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

@class Camera, CameraView, Forage, MotionCapture, RouterCable, RouterServer;

@interface MainController : UIViewController {
    
    Camera* camera;
    IBOutlet CameraView* cameraView;
    Forage* forage;
    MotionCapture* motionCapture;
    RouterCable* cable;
    RouterServer* server;
    
    int mocapContext;
    NSString* mocapHeading;
    bool mocapMonitor;
    
    NSString* evolvedParameters;
}

@end