//
//  JSQSBMessage.h
//  SendBirdChatObjC
//
//  Created by David Park on 8/16/16.
//  Copyright © 2016 DavidVYPark. All rights reserved.
//

#import <JSQMessagesViewController/JSQMessagesViewController.h>
#import <SendBirdSDK/SendBirdSDK.h>
#import "JSQMessage.h"

@interface JSQSBMessage : JSQMessage

@property (strong, nonnull) SBDBaseMessage *message;

@end
