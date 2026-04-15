#import "LiteRTBridge.h"
#import <dlfcn.h>

static NSString * const kLiteRTBridgeErrorDomain = @"com.example.xeye.litert.bridge";

typedef NS_ENUM(NSInteger, LiteRTBridgeErrorCode) {
    LiteRTBridgeErrorModelPathMissing = 1,
    LiteRTBridgeErrorModelPathInvalid = 2,
    LiteRTBridgeErrorNotInitialized = 3,
    LiteRTBridgeErrorRuntimeMissing = 4,
    LiteRTBridgeErrorRuntimeSymbolMissing = 5,
    LiteRTBridgeErrorRuntimeFailure = 6,
};

typedef int (*LiteRTCreateFn)(const char *model_path, void **out_engine, char **out_error);
typedef int (*LiteRTInferFn)(void *engine,
                             const uint8_t *rgba,
                             int width,
                             int height,
                             int bytes_per_row,
                             const char *prompt,
                             char **out_text,
                             char **out_error);
typedef void (*LiteRTDestroyFn)(void *engine);
typedef void (*LiteRTFreeCStringFn)(char *value);

@interface LiteRTBridge ()
@property(nonatomic, copy, nullable) NSString *modelPath;
@property(nonatomic, assign) BOOL initialized;
@property(nonatomic, assign) void *runtimeHandle;
@property(nonatomic, assign) void *engineHandle;
@property(nonatomic, assign) LiteRTCreateFn createFn;
@property(nonatomic, assign) LiteRTInferFn inferFn;
@property(nonatomic, assign) LiteRTDestroyFn destroyFn;
@property(nonatomic, assign) LiteRTFreeCStringFn freeCStringFn;
@end

@implementation LiteRTBridge

- (BOOL)resolveRuntimeSymbolsFromHandle:(void *)handle {
    self.createFn = reinterpret_cast<LiteRTCreateFn>(dlsym(handle, "litertlm_create"));
    self.inferFn = reinterpret_cast<LiteRTInferFn>(dlsym(handle, "litertlm_infer_rgba"));
    self.destroyFn = reinterpret_cast<LiteRTDestroyFn>(dlsym(handle, "litertlm_destroy"));
    self.freeCStringFn = reinterpret_cast<LiteRTFreeCStringFn>(dlsym(handle, "litertlm_free_string"));
    return self.createFn && self.inferFn && self.destroyFn && self.freeCStringFn;
}

- (NSArray<NSString *> *)runtimeCandidatePaths {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];

    NSString *envPath = NSProcessInfo.processInfo.environment[@"X_EYE_LITERT_BRIDGE_DYLIB"];
    if (envPath.length > 0) {
        [candidates addObject:envPath];
    }

    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    [candidates addObject:[bundlePath stringByAppendingPathComponent:@"Frameworks/LiteRTLMBridge.framework/LiteRTLMBridge"]];
    [candidates addObject:[bundlePath stringByAppendingPathComponent:@"Frameworks/libLiteRTLMBridge.dylib"]];
    [candidates addObject:[bundlePath stringByAppendingPathComponent:@"libLiteRTLMBridge.dylib"]];

    return candidates;
}

- (BOOL)loadRuntime:(NSError * _Nullable * _Nullable)error {
    NSArray<NSString *> *candidates = [self runtimeCandidatePaths];
    NSMutableArray<NSString *> *attempts = [NSMutableArray array];

    for (NSString *candidate in candidates) {
        void *handle = dlopen(candidate.UTF8String, RTLD_NOW | RTLD_LOCAL);
        if (!handle) {
            const char *dlError = dlerror();
            NSString *reason = dlError ? [NSString stringWithUTF8String:dlError] : @"unknown dlopen error";
            [attempts addObject:[NSString stringWithFormat:@"%@ (%@)", candidate, reason]];
            continue;
        }

        self.runtimeHandle = handle;
        if (![self resolveRuntimeSymbolsFromHandle:handle]) {
            [self shutdown];
            if (error != NULL) {
                *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                             code:LiteRTBridgeErrorRuntimeSymbolMissing
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"LiteRT bridge dylib loaded but missing required C symbols at path: %@", candidate]}];
            }
            return NO;
        }

        return YES;
    }

    // Development fallback: use symbols linked into the app binary itself.
    if ([self resolveRuntimeSymbolsFromHandle:RTLD_DEFAULT]) {
        self.runtimeHandle = NULL;
        return YES;
    }

    if (error != NULL) {
        *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                     code:LiteRTBridgeErrorRuntimeMissing
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"LiteRT bridge runtime library not found and no in-app ABI symbols were available. Tried: %@", [attempts componentsJoinedByString:@" | "]]}];
    }
    return NO;
}

- (BOOL)initializeWithModelPath:(NSString *)modelPath
                          error:(NSError * _Nullable * _Nullable)error {
    if (modelPath.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                         code:LiteRTBridgeErrorModelPathMissing
                                     userInfo:@{NSLocalizedDescriptionKey: @"LiteRT model path is empty."}];
        }
        [self shutdown];
        return NO;
    }

    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:modelPath];
    if (!exists) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                         code:LiteRTBridgeErrorModelPathInvalid
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"LiteRT model path does not exist: %@", modelPath]}];
        }
        [self shutdown];
        return NO;
    }

    if (![self loadRuntime:error]) {
        [self shutdown];
        return NO;
    }

    char *runtimeError = NULL;
    void *engine = NULL;
    int result = self.createFn(modelPath.UTF8String, &engine, &runtimeError);
    if (result != 0 || engine == NULL) {
        NSString *reason = @"unknown runtime create failure";
        if (runtimeError != NULL) {
            reason = [NSString stringWithUTF8String:runtimeError];
            self.freeCStringFn(runtimeError);
        }
        if (error != NULL) {
            *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                         code:LiteRTBridgeErrorRuntimeFailure
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"LiteRT runtime create failed: %@", reason]}];
        }
        [self shutdown];
        return NO;
    }

    self.engineHandle = engine;
    self.modelPath = modelPath;
    self.initialized = YES;
    return YES;
}

- (nullable NSString *)examineImageData:(NSData *)imageData
                                 prompt:(NSString *)prompt
                                  width:(int64_t)width
                                 height:(int64_t)height
                            bytesPerRow:(int64_t)bytesPerRow
                                  error:(NSError * _Nullable * _Nullable)error {
    if (!self.initialized) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                         code:LiteRTBridgeErrorNotInitialized
                                     userInfo:@{NSLocalizedDescriptionKey: @"LiteRT bridge is not initialized."}];
        }
        return nil;
    }

    if (imageData.length == 0 || width <= 0 || height <= 0 || bytesPerRow <= 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                         code:LiteRTBridgeErrorRuntimeFailure
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid input image for LiteRT inference."}];
        }
        return nil;
    }

    if (prompt.length == 0) {
        prompt = @"Describe the image briefly.";
    }

    char *outText = NULL;
    char *outError = NULL;
    int result = self.inferFn(self.engineHandle,
                              static_cast<const uint8_t *>(imageData.bytes),
                              static_cast<int>(width),
                              static_cast<int>(height),
                              static_cast<int>(bytesPerRow),
                              prompt.UTF8String,
                              &outText,
                              &outError);

    if (result != 0 || outText == NULL) {
        NSString *reason = @"unknown runtime infer failure";
        if (outError != NULL) {
            reason = [NSString stringWithUTF8String:outError];
            self.freeCStringFn(outError);
        }
        if (error != NULL) {
            *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                         code:LiteRTBridgeErrorRuntimeFailure
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"LiteRT runtime infer failed: %@", reason]}];
        }
        if (outText != NULL) {
            self.freeCStringFn(outText);
        }
        return nil;
    }

    NSString *response = [NSString stringWithUTF8String:outText];
    self.freeCStringFn(outText);
    if (outError != NULL) {
        self.freeCStringFn(outError);
    }

    if (response.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kLiteRTBridgeErrorDomain
                                         code:LiteRTBridgeErrorRuntimeFailure
                                     userInfo:@{NSLocalizedDescriptionKey: @"LiteRT returned an empty response."}];
        }
        return nil;
    }

    return response;
}

- (void)shutdown {
    if (self.engineHandle != NULL && self.destroyFn != NULL) {
        self.destroyFn(self.engineHandle);
    }
    self.engineHandle = NULL;

    if (self.runtimeHandle != NULL) {
        dlclose(self.runtimeHandle);
    }
    self.runtimeHandle = NULL;

    self.createFn = NULL;
    self.inferFn = NULL;
    self.destroyFn = NULL;
    self.freeCStringFn = NULL;
    self.modelPath = nil;
    self.initialized = NO;
}

- (void)dealloc {
    [self shutdown];
}

@end
