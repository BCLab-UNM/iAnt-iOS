//
//  DebugView.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 8/19/14.
//
//

#import "DebugView.h"
#import "Forage.h"
#import "MainController.h"

@implementation DebugView

@synthesize delegate;
@synthesize table, driveSwitch, turnSwitch;
@synthesize labels;
@synthesize data;

- (id)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    if (self) {
        labels = [[NSArray alloc] initWithObjects: @"x", @"y", @"heading", nil];
        data = [[NSMutableDictionary alloc] init];
        [data setObject:[NSNumber numberWithInt:0] forKey:@"total"];
    }
    return self;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if([delegate respondsToSelector:@selector(swapView:)]) {
        [delegate swapView:self];
    }
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString* identifier = @"cell";
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[cell textLabel] setAdjustsFontSizeToFitWidth:true];
    }
    
    NSString* label = [labels objectAtIndex:[indexPath item]];
    [[cell textLabel] setText:[[data objectForKey:label] stringValue]];
    [[cell detailTextLabel] setText:label];
    
    return cell;
}


//Recognize when switches are triggered and copy the result to Forage
- (IBAction)driveToggle:(id)sender {
    [[self forage] setDriveEnabled:[sender isOn]];
}

- (IBAction)turnToggle:(id)sender {
    [[self forage] setTurnEnabled:[sender isOn]];
}

@end
