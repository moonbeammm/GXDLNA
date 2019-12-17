//  GXDLNADMControl.m
//
//  Created by sgx on 2019/11/28.
//

#import "GXDLNADMControl.h"
#import "GXDLNAMediaController.h"
#import "Platinum.h"
#import "GXDLNAResponseModel.h"
#import "GXDLNAPositionInfoModel.h"

@interface GXDLNADMControl ()
{
    PLT_UPnP * _upnp;
    PLT_MicroMediaController * _dmc;
    NSTimer *_playerTimer;
}
@end

@implementation GXDLNADMControl

+ (GXDLNADMControl *)shared
{
    static GXDLNADMControl * instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GXDLNADMControl alloc] init];
    });
    return instance;
}
/**
 媒体控制器相关(DMC)
 */
- (instancetype)init {
    if (self = [super init]) {
        _upnp = new PLT_UPnP();
        PLT_CtrlPointReference ctrlPoint(new PLT_CtrlPoint());
        _upnp->AddCtrlPoint(ctrlPoint);
        _dmc = new PLT_MicroMediaController(ctrlPoint,self);
    }
    return self;
}

- (void)dealloc {
    delete _upnp;
    delete _dmc;
}

/**
 启动媒体控制器
 */
- (void)start {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (!_upnp->IsRunning()) {
            _upnp->Start();
        } else {
            NSLog(@"投屏GXDLNADMControl:_upnp Service is starting!");
        }
    });
}

/**
 停止
 */
- (void)connectStop {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (_upnp->IsRunning() && _upnp != NULL) {
            [self cancelTimer];
            _upnp->Stop();
        }
    });
}

/**
是否正在连接
*/
- (BOOL)isRunning {
    if (_upnp->IsRunning()) {
        return YES;
    }else{
        return NO;
    }
}

/**
 获取附近媒体渲染器(DMR)
 */
- (NSArray <GXDLNADeviceInfoModel *> *)getActiveRenders {
    NSMutableArray<GXDLNADeviceInfoModel *> * renderArray = [NSMutableArray array];
    const NPT_Lock<PLT_DeviceMap>& deviceList = _dmc->getMediaRenderersNameTable();
    const NPT_List<PLT_DeviceMapEntry*>& entries = deviceList.GetEntries();
    NPT_List<PLT_DeviceMapEntry*>::Iterator entry = entries.GetFirstItem();
    while (entry) {
        PLT_DeviceDataReference device = (*entry)->GetValue();
        GXDLNADeviceInfoModel * DMRModel = [[self class] deviceInfoModelFromDevice:device];
        [renderArray addObject:DMRModel];
        ++entry;
    }
    return [renderArray copy];
}

/**
 使用uuid选择一个媒体渲染器
 @param uuid 传入uuid
 */
- (void)chooseRenderWithUUID:(NSString *)uuid {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self cancelTimer];
        if (![uuid isEqualToString:@""]) {
            _dmc -> chooseMediaRenderer([uuid UTF8String]);
        } else {
            NSLog(@"投屏GXDLNADMControl:UUID is nil when CHOOSE Render !");
        }
    });
}

/**
 获取当前的媒体渲染器
 */
- (GXDLNADeviceInfoModel *)getCurrentRender {
    PLT_DeviceDataReference device = _dmc->getCurrentMediaRenderer();
    if (!device.IsNull()) {
        GXDLNADeviceInfoModel * DMRModel = [[self class] deviceInfoModelFromDevice:device];
        return DMRModel;
    } else {
        NSLog(@"投屏GXDLNADMControl:Render device is nil in %s",__FUNCTION__);
        return nil;
    }
}
- (void)OnGetPositionInfoResult {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ([self isExistDMR]) {
            _dmc->getRendererPositionInfo();
        }
    });
}
- (void)delegateOnGetPositionInfoResult:(GXDLNAPositionInfoModel *)positionInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.playDelegate respondsToSelector:@selector(dmc:currentTime:playableDuration:duration:)]) {
            [self.playDelegate dmc:self currentTime:positionInfo.absTime playableDuration:positionInfo.duration duration:positionInfo.duration];
        }
    });
}
/**
 播放
 */
- (void)renderPlay {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ([self isExistDMR]) {
            _dmc->setRendererPlay();
            [self startPlayerTimer];
        }
    });
}

/**
 暂停
 */
- (void)renderPause {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ([self isExistDMR]) {
            _dmc->setRendererPause();
        }
    });
}

/**
 进度调节
 @param seekTime 调节进度的位置，单位秒
 */
- (void)seekTo:(NSTimeInterval)seekTime {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ([self isExistDMR]) {
            _dmc->sendSeekCommand(seekTime);
        }
    });
}

/**
 媒体渲染器停止
 */
- (void)renderStop {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ([self isExistDMR]) {
            _dmc->setRendererStop();
            [self cancelTimer];
        }
    });
}

/**
 设置当前播放URI
 @param uriStr URI
 @param didl DIDL
 */
- (void)renderSetAVTransportWithURI:(NSString *)uriStr metaData:(NSString *)didl {
    if (didl == nil) {
        didl = @"";
    }
    [self cancelTimer];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ([self isExistDMR]) {
            _dmc->setRendererAVTransportURI([uriStr UTF8String], [didl UTF8String]);
        }
    });
}

/**
 设置音量
 @param volume 传入音量
 */
- (void)renderSetVolume:(int)volume {
    if (volume <= 0) {
        volume = 0;
    }
    if (volume >= 100) {
        volume = 100;
    }
    if ([self isExistDMR]) {
        _dmc->setRendererVolume(volume);
    }
}
/// 获取当前音量
- (void)renderGetVolome {
    _dmc->getRendererVolume();
}

#pragma mark - player timer

- (NSTimer *)initializePlayerTimer {
    if (!_playerTimer) {
        _playerTimer = [NSTimer timerWithTimeInterval:0.8 target:self selector:@selector(OnGetPositionInfoResult) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_playerTimer forMode:NSRunLoopCommonModes];
    }
    return _playerTimer;
}

- (void)startPlayerTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self initializePlayerTimer];
        [_playerTimer setFireDate:[NSDate date]];
    });
}

- (void)cancelTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_playerTimer) {
            [self->_playerTimer invalidate];
            self->_playerTimer = nil;
        }
    });
}

#pragma mark - GXDLNAMediaControllerInterface

- (void)onDMRAdded {
    NSArray *services = [[self getActiveRenders] mutableCopy];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.searchDelegate && [self.searchDelegate respondsToSelector:@selector(dmc:didFindServices:)]) {
            [self.searchDelegate dmc:self didFindServices:services];
        }
    });
}

/**
 移除DMR
 */
- (void)onDMRRemoved {
    [self onDMRAdded];
}

- (void)DMRStateViriablesChanged:(NSArray <GXDLNAResponseModel *> *)response {
    [response enumerateObjectsUsingBlock:^(GXDLNAResponseModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        GXDLNAPlayStatus playStatus = GXDLNAPlayStatusUnkown;
        if ([obj.eventName isEqualToString:@"TransportState"]) {
            if ([obj.eventValue isEqualToString:@"STOPPED"]) {
                playStatus = GXDLNAPlayStatusStopped;
            } else if ([obj.eventValue isEqualToString:@"PLAYING"]) {
                playStatus = GXDLNAPlayStatusPlaying;
            } else if ([obj.eventValue isEqualToString:@"PAUSED_PLAYBACK"]) {
                playStatus = GXDLNAPlayStatusPause;
            }
        } else if ([obj.eventName isEqualToString:@"TransportStatus"]) {
            if ([obj.eventValue isEqualToString:@"STOPPED"]) {
                
            } else if ([obj.eventValue isEqualToString:@"OK"]) {
                
            }
        } else if ([obj.eventName isEqualToString:@"CurrentPlayMode"]) {
            if ([obj.eventValue isEqualToString:@"NORMAL"]) {
                
            }
        }
        if (playStatus > 0 && self.playDelegate && [self.playDelegate respondsToSelector:@selector(dmc:playStatus:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.playDelegate dmc:self playStatus:playStatus];
            });
        }
    }];
}
- (void)playResponse:(GXDLNAResultResponseModel *)response {
    if (self.playDelegate && [self.playDelegate respondsToSelector:@selector(dmc:playStatus:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playDelegate dmc:self playStatus:GXDLNAPlayStatusPlaying];
        });
    }
}
- (void)pasuseResponse:(GXDLNAResultResponseModel *)response {
    if (self.playDelegate && [self.playDelegate respondsToSelector:@selector(dmc:playStatus:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playDelegate dmc:self playStatus:GXDLNAPlayStatusPause];
        });
    }
}
- (void)stopResponse:(GXDLNAResultResponseModel *)response {
    if (self.playDelegate && [self.playDelegate respondsToSelector:@selector(dmc:playStatus:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playDelegate dmc:self playStatus:GXDLNAPlayStatusStopped];
        });
    }
}

#pragma mark - Helper

/// 当前是否连接着投屏设备
- (BOOL)isExistDMR {
    PLT_DeviceDataReference device = _dmc->getCurrentMediaRenderer();
    if (!device.IsNull()) {
        return YES;
    } else {
        return NO;
    }
}

/// 将c++类型的device转成oc类型的deviceModel
+ (GXDLNADeviceInfoModel *)deviceInfoModelFromDevice:(PLT_DeviceDataReference)device {
    GXDLNADeviceInfoModel *DMRModel = [[GXDLNADeviceInfoModel alloc] init];
    DMRModel.name = [NSString stringWithUTF8String:device->GetFriendlyName()];
    DMRModel.uuid = [NSString stringWithUTF8String:device->GetUUID()];
    DMRModel.manufacturer = [NSString stringWithUTF8String:device->m_Manufacturer];
    DMRModel.modelName = [NSString stringWithUTF8String:device->m_ModelName];
    DMRModel.modelNumber = [NSString stringWithUTF8String:device->m_ModelNumber];
    DMRModel.serialNumber = [NSString stringWithUTF8String:device->m_SerialNumber];
    DMRModel.descriptionURL = [NSString stringWithUTF8String:device->GetDescriptionUrl()];
    return DMRModel;
}

@end
