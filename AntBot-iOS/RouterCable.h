#import <Foundation/Foundation.h>
#import "Router.h"
#import "RscMgr.h"

@interface RouterCable : Router <RscMgrDelegate> {
    RscMgr* rscMgr;
}

@end
