//
//  QRReaderController.h
//  AntBot
//
//  Created by Joshua Hecker on 6/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "CableManager.h"
#import "ScannerKit.h"

@interface QRReaderController : SKScannerViewController <RscMgrDelegate>

//<ZBarReaderViewDelegate,RscMgrDelegate>
{
    //ZBarReaderView *readerView;
    IBOutlet UITextView *infoBox;
    CableManager *cblMgr;
}

//@property (nonatomic, retain) IBOutlet ZBarReaderView *readerView;

@end
