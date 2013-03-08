//
//  AmbientLight.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import <UIKit/UIKit.h>
#import <IOKit/hid/IOHIDEventSystem.h>

@interface AmbientLight : NSObject {
    //IOHIDEventSystemRef system;
}

- (void)start;
- (void)stop;

- (AmbientLight*)ambientLight;

@end
