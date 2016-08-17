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
		[self.channel enterChannelWithCompletionHandler:^(SBDError * _Nullable error) {
			[self loadMessages:LLONG_MAX initial:YES];
		}];
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

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath {

	JSQSBMessage *currentMessage = [self.messages objectAtIndex:indexPath.item];
	if ([[currentMessage senderId] isEqualToString:self.senderId]) {
		return 0.0f;
	}
	
	if (indexPath.item - 1 > 0) {
		JSQSBMessage *previousMessage = [self.messages objectAtIndex:indexPath.item - 1];
		if ([[previousMessage senderId] isEqualToString:[currentMessage senderId]]) {
			return 0.0f;
		}
	}
	
	return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath {
	return 0.0f;
}

#pragma mark - Responding to collection view tap events

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
				header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender {
	NSLog(@"Load earlier messages!");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath {
	NSLog(@"Tapped avatar!");
	
	//GO TO USER PROFILE PAGE
}

#pragma mark - JSQMessagesComposerTextViewPasteDelegate methods

- (BOOL)composerTextView:(JSQMessagesComposerTextView *)textView shouldPasteWithSender:(id)sender {
	return YES;
}

- (void)didPressSendButton:(UIButton *)button
		   withMessageText:(NSString *)text
				  senderId:(NSString *)senderId
		 senderDisplayName:(NSString *)senderDisplayName
					  date:(NSDate *)date {
	
	
	if ([text length] > 0) {
		[self.channel sendUserMessage:text completionHandler:^(SBDUserMessage * _Nullable userMessage, SBDError * _Nullable error) {
			if (error != nil) {
				NSLog(@"Error: %@", error);
			}
			else {
				if ([userMessage createdAt] > self.lastMessageTimestamp) {
					self.lastMessageTimestamp = [userMessage createdAt];
				}
				
				if ([userMessage createdAt] < self.firstMessageTimestamp) {
					self.firstMessageTimestamp = [userMessage createdAt];
				}
				
				JSQSBMessage *jsqsbmsg = nil;
				
				NSString *senderId = [[userMessage sender] userId];
				NSString *senderImage = [[userMessage sender] profileUrl];
				NSString *senderName = [[userMessage sender] nickname];
				NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:[userMessage createdAt] / 1000];
				NSString *messageText = [userMessage message];
				
				UIImage *placeholderImage = [JSQMessagesAvatarImageFactory circularAvatarPlaceholderImage:@"TC"
																						  backgroundColor:[UIColor lightGrayColor]
																								textColor:[UIColor darkGrayColor]
																									 font:[UIFont systemFontOfSize:13.0f]
																								 diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
				JSQMessagesAvatarImage *avatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImageURL:senderImage
																						 highlightedImageURL:senderImage
																							placeholderImage:placeholderImage
																									diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
				
				[self.avatars setObject:avatarImage forKey:senderId];
				if (senderName != nil) {
					[self.users setObject:senderName forKey:senderId];
				}
				else {
					[self.users setObject:@"UK" forKey:senderId];
				}
				
				jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate text:messageText];
				jsqsbmsg.message = userMessage;
				
				[self.messages addObject:jsqsbmsg];
				
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_USEC)), dispatch_get_main_queue(), ^{
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.collectionView reloadData];
						[self scrollToBottomAnimated:NO];
						
						[[[self.inputToolbar contentView] textView] setText:@""];
					});
				});
			}
		}];
	}
}

- (void)didPressAccessoryButton:(UIButton *)sender {
	UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
	mediaUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	NSMutableArray *mediaTypes = [[NSMutableArray alloc] initWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
	mediaUI.mediaTypes = mediaTypes;
	[mediaUI setDelegate:self];
	[self presentViewController:mediaUI animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	
	__block NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
	__block UIImage *originalImage, *editedImage, *imageToUse;
	__block NSURL *imagePath;
	__block NSString *imageName;
	__block NSString *imageType;
	
	__weak AgoraViewController *weakSelf = self;
	[picker dismissViewControllerAnimated:YES completion:^{
		AgoraViewController *strongSelf = weakSelf;
		if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
			editedImage = (UIImage *) [info objectForKey:
									   UIImagePickerControllerEditedImage];
			originalImage = (UIImage *) [info objectForKey:
										 UIImagePickerControllerOriginalImage];
			NSURL *refUrl = [info objectForKey:UIImagePickerControllerReferenceURL];
			imageName = [refUrl lastPathComponent];
			
			if (originalImage) {
				imageToUse = originalImage;
			} else {
				imageToUse = editedImage;
			}
			
			imagePath = [info objectForKey:@"UIImagePickerControllerReferenceURL"];
			imageName = [imagePath lastPathComponent];
			
			CGFloat newWidth = 0;
			CGFloat newHeight = 0;
			if (imageToUse.size.width > imageToUse.size.height) {
				newWidth = 450;
				newHeight = newWidth * imageToUse.size.height / imageToUse.size.width;
			}
			else {
				newHeight = 450;
				newWidth = newHeight * imageToUse.size.width / imageToUse.size.height;
			}
			
			UIGraphicsBeginImageContextWithOptions(CGSizeMake(newWidth, newHeight), NO, 0.0);
			[imageToUse drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
			UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();
			
			
			NSData *imageFileData = nil;
			NSString *extentionOfFile = [imageName substringFromIndex:[imageName rangeOfString:@"."].location + 1];
			
			if ([extentionOfFile caseInsensitiveCompare:@"png"]) {
				imageType = @"image/png";
				imageFileData = UIImagePNGRepresentation(newImage);
			}
			else {
				imageType = @"image/jpg";
				imageFileData = UIImageJPEGRepresentation(newImage, 1.0);
			}
			
			[strongSelf.channel sendFileMessageWithBinaryData:imageFileData filename:imageName type:imageType size:imageFileData.length data:@"" completionHandler:^(SBDFileMessage * _Nullable fileMessage, SBDError * _Nullable error) {
				if (error != nil) {
					return;
				}
				
				if (fileMessage != nil) {
					NSString *senderId = [[fileMessage sender] userId];
					NSString *senderImage = [[fileMessage sender] profileUrl];
					NSString *senderName = [[fileMessage sender] nickname];
					NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:[fileMessage createdAt] / 1000];
					NSString *url = [fileMessage url];
					
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
					
					JSQPhotoMediaItem *photoItem = [[JSQPhotoMediaItem alloc] initWithImageURL:url];
					JSQSBMessage *jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate media:photoItem];
					
					[strongSelf.messages addObject:jsqsbmsg];
					
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_USEC)), dispatch_get_main_queue(), ^{
						dispatch_async(dispatch_get_main_queue(), ^{
							[strongSelf.collectionView reloadData];
							[strongSelf scrollToBottomAnimated:NO];
						});
					});
				}
			}];
		}
		else if (CFStringCompare ((CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
			NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
			NSData *videoFileData = [NSData dataWithContentsOfURL:videoURL];
			imageName = [videoURL lastPathComponent];
			
			NSString *extentionOfFile = [imageName substringFromIndex:[imageName rangeOfString:@"."].location + 1];
			
			if ([extentionOfFile caseInsensitiveCompare:@"mov"]) {
				imageType = @"video/quicktime";
			}
			else if ([extentionOfFile caseInsensitiveCompare:@"mp4"]) {
				imageType = @"video/mp4";
			}
			else {
				imageType = @"video/mpeg";
			}
			
			[strongSelf.channel sendFileMessageWithBinaryData:videoFileData filename:imageName type:imageType size:videoFileData.length data:@"" completionHandler:^(SBDFileMessage * _Nullable fileMessage, SBDError * _Nullable error) {
				if (error != nil) {
					return;
				}
				
				if (fileMessage != nil) {
					NSString *senderId = [[fileMessage sender] userId];
					NSString *senderImage = [[fileMessage sender] profileUrl];
					NSString *senderName = [[fileMessage sender] nickname];
					NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:[fileMessage createdAt] / 1000];
					NSString *url = [fileMessage url];
					
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
					
					JSQVideoMediaItem *videoItem = [[JSQVideoMediaItem alloc] initWithFileURL:[NSURL URLWithString:url] isReadyToPlay:YES];
					JSQSBMessage *jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate media:videoItem];
					
					[strongSelf.messages addObject:jsqsbmsg];
					
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_USEC)), dispatch_get_main_queue(), ^{
						dispatch_async(dispatch_get_main_queue(), ^{
							[strongSelf.collectionView reloadData];
							[strongSelf scrollToBottomAnimated:NO];
						});
					});
				}
			}];
		}
	}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:^{ }];
}

#pragma mark - SBDConnectionDelegate

- (void)didStartReconnection {
	NSLog(@"didStartReconnection in AgoraViewController");
	self.lastMessageTimestamp = LLONG_MIN;
	self.firstMessageTimestamp = LLONG_MAX;
	
	[self.messages removeAllObjects];
	[self.collectionView reloadData];
}

- (void)didSucceedReconnection {
	NSLog(@"didSucceedReconnection delegate in AgoraViewController");
	self.previousMessageQuery = [self.channel createPreviousMessageListQuery];
	[self loadMessages:LLONG_MAX initial:YES];
}

- (void)didFailReconnection {
	NSLog(@"didFailReconnection delegate in AgoraViewController");
}

#pragma mark - SBDBaseChannelDelegate

- (void)channel:(SBDBaseChannel * _Nonnull)sender didReceiveMessage:(SBDBaseMessage * _Nonnull)message {
	NSLog(@"channel:didReceiveMessage: delegate in OpenChatViewController");
	
	JSQSBMessage *jsqsbmsg = nil;
	
	if (![sender.channelUrl isEqualToString:self.channel.channelUrl]) {
		return;
	}
	
	if ([message isKindOfClass:[SBDUserMessage class]]) {
		NSString *senderId = [[((SBDUserMessage *)message) sender] userId];
		NSString *senderImage = [[((SBDUserMessage *)message) sender] profileUrl];
		NSString *senderName = [[((SBDUserMessage *)message) sender] nickname];
		NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:[message createdAt] / 1000];
		NSString *messageText = [((SBDUserMessage *)message) message];
		
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
	}
	else if ([message isKindOfClass:[SBDFileMessage class]]) {
		NSString *senderId = [[((SBDFileMessage *)message) sender] userId];
		NSString *senderImage = [[((SBDFileMessage *)message) sender] profileUrl];
		NSString *senderName = [[((SBDFileMessage *)message) sender] nickname];
		NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:[message createdAt] / 1000];
		NSString *url = [((SBDFileMessage *)message) url];
		
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
		
		JSQPhotoMediaItem *photoItem = [[JSQPhotoMediaItem alloc] initWithImageURL:url];
		jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:senderId senderDisplayName:senderName date:msgDate media:photoItem];
	}
	else if ([message isKindOfClass:[SBDAdminMessage class]]) {
		NSDate *msgDate = [NSDate dateWithTimeIntervalSince1970:[message createdAt] / 1000];
		NSString *messageText = [((SBDUserMessage *)message) message];
		
		jsqsbmsg = [[JSQSBMessage alloc] initWithSenderId:@"" senderDisplayName:@"" date:msgDate text:messageText];
		jsqsbmsg.message = message;
	}
	
	if ([message createdAt] > self.lastMessageTimestamp) {
		self.lastMessageTimestamp = [message createdAt];
	}
	
	if ([message createdAt] < self.firstMessageTimestamp) {
		self.firstMessageTimestamp = [message createdAt];
	}
	
	if (jsqsbmsg != nil) {
		[self.messages addObject:jsqsbmsg];
	}
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_USEC)), dispatch_get_main_queue(), ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.collectionView reloadData];
			[self scrollToBottomAnimated:NO];
		});
	});
}

- (void)channelDidUpdateReadReceipt:(SBDGroupChannel * _Nonnull)sender {
	NSLog(@"didReceiveChannelEvent:channelEvent: delegate in AgoraViewController");
}

- (void)channelDidUpdateTypingStatus:(SBDGroupChannel * _Nonnull)sender {
	NSLog(@"channelDidUpdateTypingStatus: delegate in AgoraViewController");
}

- (void)channel:(SBDGroupChannel * _Nonnull)sender userDidJoin:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userDidJoin: delegate in AgoraViewController");
}

- (void)channel:(SBDGroupChannel * _Nonnull)sender userDidLeave:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userDidLeave: delegate in AgoraViewController");
}

- (void)channel:(SBDOpenChannel * _Nonnull)sender userDidEnter:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userDidEnter: delegate in AgoraViewController");
}

- (void)channel:(SBDOpenChannel * _Nonnull)sender userDidExit:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userDidExit: delegate in AgoraViewController");
}

- (void)channel:(SBDOpenChannel * _Nonnull)sender userWasMuted:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userWasMuted: delegate in AgoraViewController");
}

- (void)channel:(SBDOpenChannel * _Nonnull)sender userWasUnmuted:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userWasUnmuted: delegate in AgoraViewController");
}

- (void)channel:(SBDOpenChannel * _Nonnull)sender userWasBanned:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userWasBanned: delegate in AgoraViewController");
}

- (void)channel:(SBDOpenChannel * _Nonnull)sender userWasUnbanned:(SBDUser * _Nonnull)user {
	NSLog(@"channel:userWasUnbanned: delegate in AgoraViewController");
}

- (void)channelWasFrozen:(SBDOpenChannel * _Nonnull)sender {
	NSLog(@"channelWasFrozen: delegate in AgoraViewController");
}

- (void)channelWasUnfrozen:(SBDOpenChannel * _Nonnull)sender {
	NSLog(@"channelWasUnfrozen: delegate in AgoraViewController");
}

- (void)channelWasChanged:(SBDBaseChannel * _Nonnull)sender {
	NSLog(@"channelWasChanged: delegate in AgoraViewController");
}

- (void)channelWasDeleted:(NSString * _Nonnull)channelUrl channelType:(SBDChannelType)channelType {
	NSLog(@"channelWasDeleted:channelType: delegate in AgoraViewController");
}

- (void)channel:(SBDBaseChannel * _Nonnull)sender messageWasDeleted:(long long)messageId {
	NSLog(@"channel:messageWasDeleted: delegate in AgoraViewController");
	
	for (JSQSBMessage *msg in self.messages) {
		if (msg.message.messageId == messageId) {
			NSUInteger row = [self.messages indexOfObject:msg];
			NSIndexPath *deletedMessageIndexPath = [NSIndexPath indexPathForRow:row inSection:0];
			
			[self.collectionView.dataSource collectionView:self.collectionView didDeleteMessageAtIndexPath:deletedMessageIndexPath];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.collectionView deleteItemsAtIndexPaths:@[deletedMessageIndexPath]];
				[self.collectionView.collectionViewLayout invalidateLayout];
			});
			
			break;
		}
	}
}


@end

