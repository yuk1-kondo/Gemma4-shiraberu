#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LiteRTBridge : NSObject

- (BOOL)initializeWithModelPath:(NSString *)modelPath
                          error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(initialize(modelPath:));

- (nullable NSString *)examineImageData:(NSData *)imageData
                                 prompt:(NSString *)prompt
                                  width:(int64_t)width
                                 height:(int64_t)height
                            bytesPerRow:(int64_t)bytesPerRow
                                  error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(examine(imageData:prompt:width:height:bytesPerRow:));

- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
