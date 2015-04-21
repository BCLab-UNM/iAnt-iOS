#import <Foundation/Foundation.h>

@class RouterCable, RouterServer;

@interface MotionCapture : NSObject {
    RouterCable* cable;
    RouterServer* server;
    
    BOOL monitoring;
    float context;
    float heading;
}

- (id)initWithCable:(RouterCable*)cable server:(RouterServer*)server;

@end
