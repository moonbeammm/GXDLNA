////  GXDLNADefine.h
//  bilianime
//
//  Created by sgx on 2019/12/2.
//

#ifndef GXDLNADefine_h
#define GXDLNADefine_h

/**
 播放状态
 */
typedef NS_ENUM(NSUInteger, GXDLNAPlayStatus) {
    GXDLNAPlayStatusUnkown = 0,    // 未知状态
    GXDLNAPlayStatusLoading,       // 视频正在加载状态
    GXDLNAPlayStatusPlaying,       // 正在播放状态
    GXDLNAPlayStatusPause,         // 暂停状态
    GXDLNAPlayStatusStopped,       // 退出播放状态
    GXDLNAPlayStatusCommpleted,    // 播放完成状态
    GXDLNAPlayStatusError,         // 播放错误
};

/**
 连接状态
 */
typedef NS_ENUM(NSUInteger, GXDLNAConnectStatus) {
    GXDLNAConnectStatusUnkown = 0,    // 未知状态
    GXDLNAConnectStatusConnected = 0, // 成功连接
    GXDLNAConnectStatusDisConnect,    // 断开连接
    GXDLNAConnectStatusError,         // 连接出错
};

#endif /* GXDLNADefine_h */
