//
//  ChatFriendsTableViewController.h
//  SendBirdChatObjC
//
//  Created by David Park on 8/16/16.
//  Copyright © 2016 DavidVYPark. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SendBirdSDK/SendBirdSDK.h>

@interface ChatFriendsTableViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic, nullable) SBDGroupChannel *currentChannel;

@end
