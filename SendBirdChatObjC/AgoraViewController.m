//
//  AgoraViewController.m
//  SendBirdChatObjC
//
//  Created by David Park on 8/16/16.
//  Copyright © 2016 DavidVYPark. All rights reserved.
//

#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

#import "AgoraViewController.h"

@interface AgoraViewController ()

@property (strong, nonnull) NSMutableDictionary *avatars;
@property (strong, nonnull) NSMutableDictionary *users;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *neutralBubbleImageData;
@property (strong, nonatomic) NSMutableArray<JSQSBMessage *> *messages;

@property (atomic) long long lastMessageTimestamp;
@property (atomic) long long firstMessageTimestamp;

@property (atomic) BOOL isLoading;
@property (atomic) BOOL hasPrev;

@property (strong, nonatomic) SBDPreviousMessageListQuery *previousMessageQuery;
@property (strong, nonnull) NSString *delegateIdentifier;

@end

@implementation AgoraViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view.
	
	self.isLoading = NO;
	self.hasPrev = YES;
	
	self.avatars = [[NSMutableDictionary alloc] init];
	self.users = [[NSMutableDictionary alloc] init];
	self.messages = [[NSMutableArray alloc] init];
	
	self.lastMessageTimestamp = LLONG_MIN;
	self.firstMessageTimestamp = LLONG_MAX;
	
	self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeMake(kJSQMessagesCollectionViewAvatarSizeDefault, kJSQMessagesCollectionViewAvatarSizeDefault);
	self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeMake(kJSQMessagesCollectionViewAvatarSizeDefault, kJSQMessagesCollectionViewAvatarSizeDefault);

	
	self.showLoadEarlierMessagesHeader = NO;
	self.collectionView.collectionViewLayout.springinessEnabled = NO;
	[self.collectionView setBounces:NO];
	
	JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
	JSQMessagesBubbleImageFactory *neutralBubbleFactory = [[JSQMessagesBubbleImageFactory alloc] initWithBubbleImage:[UIImage jsq_bubbleCompactTaillessImage] capInsets:UIEdgeInsetsZero];
	
	self.outgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:[UIColor jsq_messageBubbleLightGrayColor]];
	self.incomingBubbleImageData = [bubbleFactory incomingMessagesBubbleImageWithColor:[UIColor jsq_messageBubbleGreenColor]];
	self.neutralBubbleImageData = [neutralBubbleFactory neutralMessagesBubbleImageWithColor:[UIColor jsq_messageNeutralBubbleColor]];
	
	self.delegateIdentifier = self.description;
	
	[SBDMain addChannelDelegate:self identifier:self.delegateIdentifier];
	[SBDMain addConnectionDelegate:self identifier:self.delegateIdentifier];
	
	[self startSendBird];
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear: animated];
}

-(void)viewWillDisappear:(BOOL)animated {
	if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
		[SBDMain removeChannelDelegateForIdentifier: self.delegateIdentifier];
		[SBDMain removeConnectionDelegateForIdentifier: self.delegateIdentifier];
		
		[self.channel exitChannelWithCompletionHandler:^(SBDError * _Nullable error) {}];
	}
	
	[super viewWillDisappear: animated];
}

-(void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

-(void)startSendBird {
	if (self.channel != nil) {
		self.previousMessageQuery = [self.channel createPreviousMessageListQuery];
		[self.channel enterChannelWithCompletionHandler:^(SBDError * _Nullable error) {}];
	}
}

- (void)loadMessages:(long long)ts initial:(BOOL)initial {
	if (self.isLoading) {
		return;
	}
	
	if (!self.hasPrev) {
		return;
	}
	
	self.isLoading = YES;
	
	__weak AgoraViewController *weakSelf = self;
	[self.previousMessageQuery loadPreviousMessagesWithLimit:30 reverse:!initial completionHandler:^(NSArray<SBDBaseMessage *> * _Nullable messages, SBDError * _Nullable error) {
		AgoraViewController *strongSelf = weakSelf;
		if (error != nil) {
			NSLog(@"Loading previous message error: %@", error);
			
			return;
		}
		
		if (messages != nil && [messages count] > 0) {
			int msgCount = 0;
			
			for (SBDBaseMessage *message in messages) {
				if ([message isKindOfClass:[SBDUserMessage class]]) {
					NSLog(@"Message Type: MESG, Timestamp: %lld", message.createdAt);
				}
				else if ([message isKindOfClass:[SBDFileMessage class]]) {
					NSLog(@"Message Type: FILE, Timestamp: %lld", message.createdAt);
				}
				else if ([message isKindOfClass:[SBDAdminMessage class]]) {
					NSLog(@"Message Type: ADMM, Timestamp: %lld", message.createdAt);
				}
				
				if (message.createdAt < strongSelf.firstMessageTimestamp) {
					strongSelf.firstMessageTimestamp = message.createdAt;
				}
				
				JSQSBMessage *jsqsbmsg = nil;
				
				if ([message isKindOfClass:[SBDUserMessage class]]) {
					NSString *senderId = ((SBDUserMessage *)message).sender.userId;
					NSString *senderImage = ((SBDUserMessage *)message).sender.profileUrl;
					NSString *senderName = ((SBDUserMessage *)message).sender.nickname;
					NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:((SBDUserMessage *)message).createdAt / 1000];
					NSString *messageText = ((SBDUserMessage *)message).message;
					
					NSString *initialName = @"";
					if ([senderName length] > 1) {
						initialName = [[senderName substringWithRange:NSMakeRange(0, 2)] uppercaseString];
					}
					else if ([senderName length] > 0) {
						initialName = [[senderName substringWithRange:NSMakeRange(0, 1)] uppercaseString];
					}
					
					UIImage *placeholderImage = [JSQMessagesAvatarImageFactory circularAvatarPlaceholderImage:initialName
																							  backgroundColor:[UIColor lightGrayColor]
																									textColor:[UIColor darkGrayColor]
																										 font:[UIFont systemFontOfSize:13.0f]
																									 diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
					JSQMessagesAvatarImage *avatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImageURL:senderImage
																							 highlightedImageURL:nil
																								placeholderImage:placeholderImage
																										diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
					
					[self.avatars setObject:avatarImage forKey:senderId];
					[self.users setObject:senderName forKey:senderId];
					
					jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate text:messageText];
					jsqsbmsg.message = message;
					msgCount += 1;
				}
				else if ([message isKindOfClass:[SBDFileMessage class]]) {
					NSString *senderId = ((SBDFileMessage *)message).sender.userId;
					NSString *senderImage = ((SBDFileMessage *)message).sender.profileUrl;
					NSString *senderName = ((SBDFileMessage *)message).sender.nickname;
					NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:((SBDFileMessage *)message).createdAt / 1000];
					NSString *url = ((SBDFileMessage *)message).url;
					NSString *type = ((SBDFileMessage *)message).type;
					
					NSString *initialName = @"";
					if ([senderName length] > 1) {
						initialName = [[senderName substringWithRange:NSMakeRange(0, 2)] uppercaseString];
					}
					else if ([senderName length] > 0) {
						initialName = [[senderName substringWithRange:NSMakeRange(0, 1)] uppercaseString];
					}
					
					UIImage *placeholderImage = [JSQMessagesAvatarImageFactory circularAvatarPlaceholderImage:initialName
																							  backgroundColor:[UIColor lightGrayColor]
																									textColor:[UIColor darkGrayColor]
																										 font:[UIFont systemFontOfSize:13.0f]
																									 diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
					JSQMessagesAvatarImage *avatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImageURL:senderImage
																							 highlightedImageURL:nil
																								placeholderImage:placeholderImage
																										diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
					
					[self.avatars setObject:avatarImage forKey:senderId];
					[self.users setObject:senderName forKey:senderId];
					
					if ([type hasPrefix:@"image"]) {
						JSQPhotoMediaItem *photoItem = [[JSQPhotoMediaItem alloc] initWithImageURL:url];
						jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate media:photoItem];
					}
					else if ([type hasPrefix:@"video"]) {
						JSQVideoMediaItem *videoItem = [[JSQVideoMediaItem alloc] initWithFileURL:[NSURL URLWithString:url] isReadyToPlay:YES];
						jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate media:videoItem];
					}
					else {
						JSQFileMediaItem *fileItem = [[JSQFileMediaItem alloc] initWithFileURL:[NSURL URLWithString:url]];
						jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate media:fileItem];
					}
					jsqsbmsg.message = message;
					msgCount += 1;
				}
				else if ([message isKindOfClass:[SBDAdminMessage class]]) {
					NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:((SBDUserMessage *)message).createdAt / 1000];
					NSString *messageText = ((SBDAdminMessage *)message).message;
					
					jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:@"" senderDisplayName:@"" date:msgDate text:messageText];
					jsqsbmsg.message = message;
					msgCount += 1;
				}
				
				if (initial) {
					[self.messages addObject:jsqsbmsg];
				}
				else {
					[self.messages insertObject:jsqsbmsg atIndex:0];
				}
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.collectionView reloadData];
				
				if (initial) {
					[self scrollToBottomAnimated:NO];
				}
				else {
					unsigned long totalMsgCount = [self.collectionView numberOfItemsInSection:0];
					if (msgCount - 1 > 0 && totalMsgCount > 0) {
						[self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:(msgCount - 1) inSection:0]
													atScrollPosition:UICollectionViewScrollPositionTop
															animated:NO];
					}
				}
			});
			
			self.isLoading = NO;
		}
		else {
			self.hasPrev = NO;
			self.isLoading = NO;
		}
	}];
}

#pragma mark - JSQMessages CollectionView DataSource

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath {
	return [self.messages objectAtIndex:indexPath.item];
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didDeleteMessageAtIndexPath:(NSIndexPath *)indexPath {
	[self.messages removeObjectAtIndex:indexPath.item];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath {
	
	JSQSBMessage *message = [self.messages objectAtIndex:indexPath.item];
	
	if ([message.senderId length] == 0) {
		return self.neutralBubbleImageData;
	}
	else {
		if ([message.senderId isEqualToString:self.senderId]) {
			return self.outgoingBubbleImageData;
		}
		
		return self.incomingBubbleImageData;
	}
}

//AVATERS

- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath {

	JSQSBMessage *message = [self.messages objectAtIndex:indexPath.item];
	
	return [self.avatars objectForKey:message.senderId];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath {
	/**
	 *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
	 *  The other label text delegate methods should follow a similar pattern.
	 *
	 *  Show a timestamp for every 3rd message
	 */
	if (indexPath.item % 3 == 0) {
		JSQSBMessage *message = [self.messages objectAtIndex:indexPath.item];
		return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
	}
	
	return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath {
	JSQSBMessage *message = [self.messages objectAtIndex:indexPath.item];
	
	if ([message.senderId isEqualToString:self.senderId]) {
		return nil;
	}
	
	if (indexPath.item - 1 > 0) {
		JSQSBMessage *previousMessage = [self.messages objectAtIndex:indexPath.item - 1];
		if ([[previousMessage senderId] isEqualToString:message.senderId]) {
			return nil;
		}
	}

	return [[NSAttributedString alloc] initWithString:message.senderDisplayName];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath {
	return nil;
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return [self.messages count];
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	
	JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
	
	/**
	 *  Configure almost *anything* on the cell
	 *
	 *  Text colors, label text, label colors, etc.
	 *
	 *  DO NOT set `cell.textView.font` !
	 *  Instead, you need to set `self.collectionView.collectionViewLayout.messageBubbleFont` to the font you want in `viewDidLoad`
	 *
	 *  DO NOT manipulate cell layout information!
	 *  Instead, override the properties you want on `self.collectionView.collectionViewLayout` from `viewDidLoad`
	 */
	
	JSQSBMessage *msg = [self.messages objectAtIndex:indexPath.item];
	
	if (!msg.isMediaMessage) {
		
		if ([msg.senderId isEqualToString:self.senderId]) {
			cell.textView.textColor = [UIColor blackColor];
			[cell setUnreadCount:0];
		}
		else {
			cell.textView.textColor = [UIColor whiteColor];
		}
		
		cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor,
											  NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
	}
	
	[cell setUnreadCount:0];
	
	if (indexPath.row == 0) {
		[self loadMessages:self.firstMessageTimestamp initial:NO];
	}
	
	return cell;
}

#pragma mark - JSQMessages collection view flow layout delegate

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath {
	/**
	 *  Each label in a cell has a `height` delegate method that corresponds to its text dataSource method
	 */
	
	/**
	 *  This logic should be consistent with what you return from `attributedTextForCellTopLabelAtIndexPath:`
	 *  The other label height delegate methods should follow similarly
	 *
	 *  Show a timestamp for every 3rd message
	 */
	if (indexPath.item % 3 == 0) {
		return kJSQMessagesCollectionViewCellLabelHeightDefault;
	}
	
	return 0.0f;
}

































@end

