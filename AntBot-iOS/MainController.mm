//
//  MainController.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "MainController.h"

@implementation MainController

const int BACK_REZ_VERT = 352;
const int BACK_REZ_HOR = 288;
const int FRONT_REZ_VERT = 192;
const int FRONT_REZ_HOR = 144;
const int NEST_THRESHOLD = 240;

@synthesize infoBox;

#pragma mark - UIView callbacks

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // QR code reader
    qrDecoder = [[Decoder alloc] init];
    NSMutableSet *readers = [[NSMutableSet alloc] init];
    QRCodeReader* qrcodeReader = [[QRCodeReader alloc] init];
    [readers addObject:qrcodeReader];
    [qrDecoder setReaders:readers];
    [qrDecoder setDelegate:self];
    
    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream opened" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream closed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInfoBox:) name:@"infoBox text" object:nil];
    
    // Server connection
    server = [[RouterServer alloc] init];
    //[server connectTo:@"192.168.1.10" onPort:2223];
    [server connectTo:@"64.106.39.146" onPort:2223];
    [server send:[NSString stringWithFormat:@"%@\n", [Utilities getMacAddress]]];
    [self initServerHandlers];
    
    // Serial cable connection
    cable = [[RouterCable alloc] init];
    [self initCableHandlers];
    
    // RelativeMotion
    relMotion = [[RelativeMotion alloc] init];
    [relMotion setCable:cable];
    
    // AbsoluteMotion
    absMotion = [[AbsoluteMotion alloc] init];
    [absMotion setCable:cable];
    
    // Mocap variables.
    mocapMonitor = false;
    mocapHeading = 0;
    mocapContext = 0;
    
    // Start forage logic thread.
    dispatch_async(dispatch_get_global_queue(0, 0), ^(void) {
        Forage* forage = [[Forage alloc] init];
        [forage loop];
    });
}

- (void)viewDidUnload {
    [self setInfoBox:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)initServerHandlers {
    
    // Mocap Heading
    [server handle:@"heading" callback:^(NSArray* data) {
        mocapHeading = [data objectAtIndex:0];
        
        //Create storage variables
        short int cmd[2] = {0, 0};
        cmd[0] = 2 * (int)[Utilities angleFrom:(int)mocapContext to:[mocapHeading intValue]];
        
        //Transmit data to Arduino
        [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
        
        //If angle is small enough, we transmit an additional command to Arduino to stop alignment
        if (abs(cmd[0]) < 2) {
            [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
            mocapMonitor = false;
        }
    }];
    
    // Tag Status
    [server handle:@"tag" callback:^(NSArray* data) {
        NSString* tagStatus = [data objectAtIndex:0];
        
        [[self infoBox] setText:[NSString stringWithFormat:@"%@ TAG FOUND     %d", [tagStatus uppercaseString], qrCode]];
        
        if(mocapMonitor) {
            // If we receive tag information while the mocapHeading is being monitored,
            // then we need to remove the mocapHeading observer and send a stop message to the Arduino
            mocapMonitor = false;
            short int cmd[2] = {0, 0};
            [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
            [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
        }
        
        [cable send:tagStatus];
        if ([tagStatus isEqualToString:@"new"]) {
            [cable send:[NSString stringWithFormat:@"%d\n", qrCode]];
        }
    }];
    
    // Pheromone Location
    [server handle:@"pheromone" callback:^(NSArray* data) {
        NSString* pheromone = [data objectAtIndex:0];
        [cable send:@"pheromone"];
        [cable send:[NSString stringWithFormat:@"%@\n", pheromone]];
    }];
}

- (void)initCableHandlers {
    
    // Align
    [cable handle:@"align" callback:^(NSArray* data) {
        int heading = [[data objectAtIndex:0] intValue];
        mocapContext = heading;
        mocapMonitor = true;
        [cable send:@"align"];
    }];
    
    // Display
    [cable handle:@"display" callback:^(NSArray* data) {
        [[self infoBox] setText:[data objectAtIndex:0]];
    }];
    
    // Fence
    [cable handle:@"fence" callback:^(NSArray* data) {
        double radius = [[data objectAtIndex:0] doubleValue];
        [absMotion enableRegionMonitoring:@"virtual fence" withRadius:radius];
    }];
    
    // Gyro on
    [cable handle:@"gyro on" callback:^(NSArray* data) {
        NSString* label = @"GYRO ON";
        if(![sensorState isEqualToString:label]) {
            [relMotion start];
            [infoBox setText:label];
            sensorState = label;
        }
        [cable send:@"gyro on"];
    }];
    
    // Gyro off
    [cable handle:@"gyro off" callback:^(NSArray* data) {
        NSString* label = @"GYRO OFF";
        if(![sensorState isEqualToString:label]) {
            [relMotion stop];
            [infoBox setText:label];
            sensorState = @"GYRO OFF";
        }
    }];
    
    // Heading
    [cable handle:@"heading" callback:^(NSArray* data) {
        [cable send:mocapHeading];
    }];
    
    // Nest on
    [cable handle:@"nest on" callback:^(NSArray* data) {
        NSString* label = @"NEST ON";
        if(![sensorState isEqualToString:label]) {
            if(imgRecog) {
                [imgRecog teardownAVCapture];
                imgRecog = nil;
            }
            imgRecog = [[ImageRecognition alloc] initResolutionTo:FRONT_REZ_VERT by:FRONT_REZ_HOR target:@"nest" view:previewView];
            [imgRecog setupAVCaptureAt:AVCaptureDevicePositionFront];
            [infoBox setText:label];
            sensorState = label;
            nestDistance = -1;
        }
        [cable send:@"nest on"];
    }];
    
    // Nest off
    [cable handle:@"nest off" callback:^(NSArray* data) {
        NSString* label = @"NEST OFF";
        if(![sensorState isEqualToString:label]) {
            [imgRecog teardownAVCapture];
            imgRecog = nil;
            [infoBox setText:label];
            sensorState = label;
        }
        [cable send:@"nest off"];
        [cable send:[NSString stringWithFormat:@"%d\n", nestDistance]];
    }];
    
    // Parameters
    [cable handle:@"parameters" callback:^(NSArray* data) {
        if(evolvedParameters) {
            [cable send:@"parameters"];
            [cable send:evolvedParameters];
        }
    }];
    
    // Print
    [cable handle:@"print" callback:^(NSArray* data){
        NSString* message = [data objectAtIndex:0];
        [server send:[NSString stringWithFormat:@"%@,%@\n", [Utilities getMacAddress], message]];
    }];
    
    // Seed
    [cable handle:@"seed" callback:^(NSArray* data) {
        [cable send:@"seed"];
        [cable send:[NSString stringWithFormat:@"%d", arc4random()]];
    }];
    
    // Tag on
    [cable handle:@"tag on" callback:^(NSArray* data) {
        NSString* label = @"TAG ON";
        if(![sensorState isEqualToString:label] && ![sensorState isEqualToString:@"TAG FOUND"]) {
            if(!imgRecog) {
                [imgRecog teardownAVCapture];
                imgRecog = nil;
            }
            
            imgRecog = [[ImageRecognition alloc] initResolutionTo:BACK_REZ_VERT by:BACK_REZ_HOR target:@"tag" view:previewView];
            [imgRecog setupAVCaptureAt:AVCaptureDevicePositionBack];
        }
        [infoBox setText:label];
        sensorState = label;
        [cable send:@"tag on"];
        qrCode = -1;
    }];
    
    // Tag off
    [cable handle:@"tag off" callback:^(NSArray* data) {
        NSString* label = @"TAG OFF";
        if(![sensorState isEqualToString:label]) {
            [imgRecog teardownAVCapture];
            imgRecog = nil;
            [infoBox setText:label];
            sensorState = label;
        }
    }];
}


#pragma mark - Notification Center

- (void)receiveNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"Stream opened"]) {
        [infoBox setBackgroundColor:[UIColor clearColor]];
        [infoBox setTextColor:[UIColor blackColor]];
    }
    else if ([[notification name] isEqualToString:@"Stream closed"]) {
        [infoBox setBackgroundColor:[UIColor redColor]];
        [infoBox setTextColor:[UIColor whiteColor]];
    }
}

- (void)updateInfoBox:(NSNotification*) notification {
    dispatch_async (dispatch_get_main_queue(), ^{
        [infoBox setText:[[notification userInfo] objectForKey:@"text"]];
    });
}

@end
