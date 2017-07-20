//
//  DHKeyManager.h
//  DHChat
//
//  Created by Phung Van Hai on 11/20/16.
//  Copyright © 2016 Phung Van Hai. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <openssl/dh.h>
#import <openssl/aes.h>
#include <openssl/conf.h>
#include <openssl/evp.h>
#include <openssl/err.h>

@interface DHKeyManager : NSObject
@property(assign, nonatomic) DH* dhKey;

+ (instancetype)getInstance;
- (instancetype)init;
- (NSData*) GetPublicKey;
- (NSData*) GetSecretKeyWithPartnerKey:(NSData*) partnerKey;
- (NSData*) EncryptDataWith: (NSData*) inputData andSecretKey: (NSData*) secretKey;
- (NSString*) DecryptDataWith: (NSData*) inputData andSecretKey: (NSData*) secretKey;
@end
