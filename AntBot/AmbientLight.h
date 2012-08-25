//
//  AmbientLight.h
//  AntBot
//
//  Created by Joshua Hecker on 7/10/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import <UIKit/UIKit.h>
#import <IOKit/hid/IOHIDEventSystem.h>

@interface AmbientLight : NSObject
{
    //IOHIDEventSystemRef system;
}

- (void)start;
- (void)stop;

- (AmbientLight*)ambientLight;

@end
