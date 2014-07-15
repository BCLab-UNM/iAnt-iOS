//
//  MainController.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "MainController.h"

#import "Forage.h"
#import "ImageRecognition.h"
#import "MotionCapture.h"
#import "RouterServer.h"
#import "RouterCable.h"
#import "Utilities.h"

#import <math.h>

@implementation MainController

@synthesize infoBox;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream opened" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream closed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"setText" object:nil];
    
    // Server connection
    //server = [[RouterServer alloc] initWithIP:@"10.0.0.7" port:2223];
    //[server send:[Utilities getMacAddress]];
    
    // Serial cable connection
    cable = [[RouterCable alloc] init];
    
    // Motion capture controller
    //motionCapture = [[MotionCapture alloc] initWithCable:cable server:server];
    
    // Forage (CPFA logic)
    forage = [[Forage alloc] initWithCable:cable server:server];
    [[forage imageRecognition] setView:previewView];
    
    // Tag Status Handler TODO delegate to Forage with NSNotificationCenter event?
    /*[server handle:@"tag" callback:^(NSArray* data) {
        [[self infoBox] setText:[NSString stringWithFormat:@"%@ TAG FOUND", [[data objectAtIndex:0] uppercaseString]]];
    }];*/
    
    [[self infoBox] setFont:[UIFont fontWithName:@"Courier New" size:8]];
}

- (void)viewDidUnload {
    [self setInfoBox:nil];
    [[forage cable] send:@"motor,0,0"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)receiveNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"Stream opened"]) {
        [infoBox setBackgroundColor:[UIColor clearColor]];
        [infoBox setTextColor:[UIColor blackColor]];
    }
    else if ([[notification name] isEqualToString:@"Stream closed"]) {
        [infoBox setBackgroundColor:[UIColor redColor]];
        [infoBox setTextColor:[UIColor whiteColor]];
    }
    else if([[notification name] isEqualToString:@"setText"]) {
        [infoBox setBackgroundColor:[UIColor clearColor]];
        [infoBox setTextColor:[UIColor blackColor]];
        [infoBox setText:[[infoBox text] stringByAppendingString:[notification object]]];
    }
}

@end
