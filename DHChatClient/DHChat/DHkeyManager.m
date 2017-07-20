//
//  DHkeyManager.m
//  DHChat
//
//  Created by Phung Van Hai on 11/20/16.
//  Copyright © 2016 Phung Van Hai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DHKeyManager.h"


@implementation DHKeyManager

+ (instancetype)getInstance {
    static DHKeyManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.dhKey = DH_new();
        DH_generate_parameters_ex(self.dhKey, 256, DH_GENERATOR_2, NULL);
        DH_generate_key(self.dhKey);
        
    }
    return self;
}

-(NSData*) GetPublicKey
{
    char* strPublicKey = BN_bn2dec(self.dhKey->pub_key);
    return [NSData dataWithBytes:strPublicKey length:strlen(strPublicKey)];
}
    
-(NSData*) GetSecretKeyWithPartnerKey:(NSData*) partnerKey
{
    BIGNUM *pubkey = NULL;
    BN_dec2bn(&pubkey, (const char*) partnerKey.bytes);
    
    unsigned char *sharedKey;
    sharedKey = (unsigned char *)OPENSSL_malloc(sizeof(unsigned char) * (DH_size(self.dhKey)));
    int secretSize = DH_compute_key(sharedKey, pubkey, self.dhKey);
    return [NSData dataWithBytes:sharedKey length:secretSize];
}
    

- (NSData*) EncryptDataWith: (NSData*) inputData andSecretKey: (NSData*) secretKey
{
    
    EVP_CIPHER_CTX *ctx;
    int len;
    int ciphertext_len;
    unsigned char *iv = (unsigned char *)"01234567890123456";
    unsigned char ciphertext[1024];
    /* Create and initialise the context */
    ctx = EVP_CIPHER_CTX_new();
    EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), NULL, (unsigned char*)secretKey.bytes, iv);
    EVP_EncryptUpdate(ctx, ciphertext, &len, inputData.bytes, inputData.length);
    ciphertext_len = len;
    EVP_EncryptFinal_ex(ctx, ciphertext + len, &len);
    ciphertext_len += len;
    /* Clean up */
    EVP_CIPHER_CTX_free(ctx);
    return [NSData dataWithBytes:ciphertext length:ciphertext_len];
}

- (NSString*) DecryptDataWith: (NSData*) inputData andSecretKey: (NSData*) secretKey
{
    
    EVP_CIPHER_CTX *ctx;
    int len;
    int plaintext_len;
    unsigned char *iv = (unsigned char *)"01234567890123456";
    unsigned char plaintext[1024];
    
    ctx = EVP_CIPHER_CTX_new();
    EVP_DecryptInit_ex(ctx, EVP_aes_256_cbc(), NULL, (unsigned char*)secretKey.bytes, iv);
    EVP_DecryptUpdate(ctx, plaintext, &len, inputData.bytes, inputData.length);
    plaintext_len = len;
    EVP_DecryptFinal_ex(ctx, plaintext + len, &len);
    plaintext_len += len;
    /* Clean up */
    EVP_CIPHER_CTX_free(ctx);
    return [NSString stringWithCString:plaintext encoding:NSASCIIStringEncoding];
    //return [NSString stringWithCharacters:plaintext length:plaintext_len];
}



@end
