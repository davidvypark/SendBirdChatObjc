//
//  ChatHomeViewController.m
//  SendBirdChatObjC
//
//  Created by David Park on 8/16/16.
//  Copyright © 2016 DavidVYPark. All rights reserved.
//

#import "ChatHomeViewController.h"

@interface ChatHomeViewController ()

@property (weak, nonatomic) IBOutlet UIButton *openAgoraButton;

@property (strong, nonatomic) NSString *delegateIdentifier;
@property (strong, nonatomic) NSMutableArray<SBDOpenChannel *> *channels;

@property (atomic) BOOL loggedIn;

@property (strong, nonatomic) SBDOpenChannelListQuery *channelListQuery;
@property (strong, nonatomic) UIRefreshControl *refreshControl;

@end

@implementation ChatHomeViewController

-(void)viewDidLoad {
	[super viewDidLoad];
	NSLog(@"number of Channel %li", self.channels.count);
	
	self.delegateIdentifier = self.description;
	[SBDMain addConnectionDelegate:self identifier:self.delegateIdentifier];
	[SBDMain addChannelDelegate:self identifier:self.delegateIdentifier];
	
	self.channels = [[NSMutableArray alloc] init];
	
	self.channelListQuery = [SBDOpenChannel createOpenChannelListQuery];
	self.loggedIn = YES;
	self.openAgoraButton.enabled = false;
	
	//*****connecWithUserID: User ID from FIRBASE*****
	[SBDMain connectWithUserId:@"DavidUserID" accessToken:@"" completionHandler:^(SBDUser * _Nullable user, SBDError * _Nullable error) {
		
		//*****CurrentUserInfoWithNickname: FROM Facebook First + Last Name*****
		[SBDMain updateCurrentUserInfoWithNickname:@"DavidNickname" profileUrl:nil completionHandler:^(SBDError * _Nullable error) {
			if (error != nil) {
				NSLog(@"User Info Updating Error: %@", error);
			}
			if (self.channels.count == 0) {
				NSLog(@"Create Open Agora");
				
				[SBDOpenChannel createChannelWithName:@"Open Agora" coverUrl:nil data:nil operatorUsers:@[[SBDMain getCurrentUser]] completionHandler:^(SBDOpenChannel * _Nullable channel, SBDError * _Nullable error) {
					if (error != nil) {
						NSLog(@"Error");
					}
					
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.channels removeAllObjects];
						self.channelListQuery = [SBDOpenChannel createOpenChannelListQuery];
						[self loadChannels];
						self.openAgoraButton.enabled = true;
					});
				}];
			}
		}];
	}];
	
}

-(void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (IBAction)openAgoraButtonTapped:(id)sender {
	
	NSString *userId = @"DavidUserID";
	NSString *userName = @"DavidParkUserName";
	
	AgoraViewController *vc = [[AgoraViewController alloc] init];
	[vc setSenderId:[SBDMain getCurrentUser].userId];
	[vc setSenderDisplayName:[SBDMain getCurrentUser].nickname];
	[vc setTitle: @"Open Agora"];
	[vc setChannel: self.channels[0]];
	
	[self.navigationController pushViewController:vc animated:YES];
}

- (void)loadChannels {
	
	[self.channelListQuery loadNextPageWithCompletionHandler:^(NSArray<SBDOpenChannel *> * _Nullable channels, SBDError * _Nullable error) {
		if (error != nil) {
			NSLog(@"Channel List Loading Error: %@", error);
			if ([self.refreshControl isRefreshing]) {
				[self.refreshControl endRefreshing];
			}
			
			return;
		}
		
		if (channels == nil && [channels count] == 0) {
			return;
		}
		
		for (SBDOpenChannel *channel in channels) {
			[self.channels addObject:channel];
		}
		
	}];
}


@end
