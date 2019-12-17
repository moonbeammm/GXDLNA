//  GXDLNADMControl.h
//
//  Created by sgx on 2019/11/28.
//

#import <Foundation/Foundation.h>
#import "GXDLNADeviceInfoModel.h"
#import "GXDLNAMediaControllerInterface.h"
#import "GXDLNADefine.h"


/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@class GXDLNADMControl;
@protocol GXDLNADMControlPlayDelegate <NSObject>

@optional

/**
 播放状态代理回调

 @param dmc 当前播放器
 @param playStatus 播放状态
 */
- (void)dmc:(GXDLNADMControl *)dmc playStatus:(GXDLNAPlayStatus)playStatus;

/**
 播放器更新时间回调.
 每800ms更新一次.
 播放器暂停时不回调.
 */
- (void)dmc:(GXDLNADMControl *)dmc currentTime:(NSTimeInterval)currentTime playableDuration:(NSTimeInterval)playableDuration duration:(NSTimeInterval)duration;

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@protocol GXDLNADMControlSearchDelegate <NSObject>

/**
发现设备代理回调：一旦设备列表有变化就会回调
内部已异步到主线程
@param dmc 当前搜索工具
@param services 设备列表
*/
- (void)dmc:(GXDLNADMControl *)dmc didFindServices:(NSArray<GXDLNADeviceInfoModel *>*)services;

@end

/*------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------*/

@interface GXDLNADMControl : NSObject <GXDLNAMediaControllerInterface>

+ (GXDLNADMControl *)shared;

@property (nonatomic, weak)id <GXDLNADMControlPlayDelegate> playDelegate;
@property (nonatomic, weak)id <GXDLNADMControlSearchDelegate> searchDelegate;

/*-------------------------------------------------------------------------------------
                                   媒体控制器相关(DMC)接口
-------------------------------------------------------------------------------------*/
/// 启动媒体控制器
- (void)start;
/// 停止
- (void)connectStop;
/// 是否正在连接
- (BOOL)isRunning;

/*-------------------------------------------------------------------------------------
                                    媒体渲染器(DMR)接口
 -------------------------------------------------------------------------------------*/
/**
 使用uuid选择一个媒体渲染器
 @param uuid 传入uuid
 */
- (void)chooseRenderWithUUID:(NSString *)uuid;
/// 获取当前的媒体渲染器
- (GXDLNADeviceInfoModel *)getCurrentRender;
/// 播放
- (void)renderPlay;
/// 暂停
- (void)renderPause;
/**
 进度调节
 @param seekTime 调节进度的位置，单位秒
 */
- (void)seekTo:(NSTimeInterval)seekTime;
/// 媒体渲染器停止
- (void)renderStop;
/**
 设置当前播放URI
 */
- (void)renderSetAVTransportWithURI:(NSString *)uriStr metaData:(NSString *)didl;
/**
 设置音量
 @param volume 传入音量
 */
- (void)renderSetVolume:(int)volume;
/// 获取当前音量
- (void)renderGetVolome;

@end
