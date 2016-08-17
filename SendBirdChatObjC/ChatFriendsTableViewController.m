//
//  ChatFriendsTableViewController.m
//  SendBirdChatObjC
//
//  Created by David Park on 8/16/16.
//  Copyright © 2016 DavidVYPark. All rights reserved.
//

#import "ChatFriendsTableViewController.h"
#import "MemberListTableViewCell.h"

@interface ChatFriendsTableViewController ()

@property (weak, nonatomic) IBOutlet UITableView *memberListTableView;

@property (strong, nonatomic) NSMutableArray<SBDUser *> *members;
@property (atomic) BOOL isLoading;

@property (atomic) NSString *userID;
@property (atomic) NSString *userName;

@property (strong, nonatomic) SBDUserListQuery *memberListQuery;
@property (strong ,nonatomic) NSString *selectedMember;

@end

@implementation ChatFriendsTableViewController

-(void)viewDidLoad {
	[super viewDidLoad];
	
	self.title = @"Friends";
	
	self.isLoading = NO;
	self.members = [[NSMutableArray alloc] init];
	
	self.memberListTableView.delegate = self;
	self.memberListTableView.dataSource = self;
	[self.memberListTableView registerNib:[MemberListTableViewCell nib] forCellReuseIdentifier:[MemberListTableViewCell cellReuseIdentifier]];
}

//I dont actually have to create an array here. I can just init a chatroom with 2 members, yourself and the person
//who's face you click.
//Just need to figure out how to add people to chatroom, init a chatroom, and yourself and the other person.
//And the other person should get an alert when a new chatroom has been init with them in it.

#pragma mark - UITableViewDelegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
	return 0;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section {
	return 0;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	//pick user at index path
	//selected User = user at index path
	//create new room
	//segue to room
}

#pragma mark - UITableViewDataSource

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 5; //number of friends
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	MemberListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[MemberListTableViewCell cellReuseIdentifier]];
	
	
	return cell;
}









@end
