//
//  MainController.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

@class AbsoluteMotion, Forage, ImageRecognition, RelativeMotion, RouterServer, RouterCable;

@interface MainController : UIViewController {
    
    AbsoluteMotion *absMotion;
    RouterServer *server;
    RouterCable *cable;
    ImageRecognition *imgRecog;
    RelativeMotion *relMotion;
    Forage* forage;
    
    IBOutlet UIView *previewView;
    
    NSString *sensorState;
    int qrCode;
    int nestDistance;
    
    int mocapContext;
    NSString* mocapHeading;
    bool mocapMonitor;
    
    NSString* evolvedParameters;
}

- (void)initServerHandlers;
- (void)initCableHandlers;

@property IBOutlet UITextView *infoBox;

@end