//
//  MainController.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

@class Forage, MotionCapture, RouterCable, RouterServer;

@interface MainController : UIViewController {
    
    Forage* forage;
    MotionCapture* motionCapture;
    RouterCable* cable;
    RouterServer* server;
    
    IBOutlet UIView* previewView;
    
    int mocapContext;
    NSString* mocapHeading;
    bool mocapMonitor;
    
    NSString* evolvedParameters;
}

@property IBOutlet UITextView* infoBox;

@end