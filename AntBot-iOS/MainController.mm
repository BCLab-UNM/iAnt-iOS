//
//  MainController.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "MainController.h"

#import "Camera.h"
#import "CameraView.h"
#import "Forage.h"
#import "ImageRecognition.h"
#import "MotionCapture.h"
#import "RouterServer.h"
#import "RouterCable.h"
#import "Utilities.h"

#import <math.h>

@implementation MainController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Camera
    camera = [[Camera alloc] init];
    [camera setView:cameraView];
    
    // Communication
    server = [[RouterServer alloc] initWithIP:@"64.106.39.136" port:2223];
    cable = [[RouterCable alloc] init];
    
    // Logic
    //motionCapture = [[MotionCapture alloc] initWithCable:cable server:server];
    forage = [[Forage alloc] initWithCable:cable server:server camera:camera];
    [[forage imageRecognition] setView:cameraView];
}

- (void)viewDidUnload {
    [[forage cable] send:@"motors,0,0"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
