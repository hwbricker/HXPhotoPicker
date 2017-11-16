//
//  HXPhoto3DTouchViewController.m
//  微博照片选择
//
//  Created by 洪欣 on 2017/9/25.
//  Copyright © 2017年 洪欣. All rights reserved.
//

#import "HXPhoto3DTouchViewController.h"
#import <PhotosUI/PhotosUI.h>
#import "UIImage+HXExtension.h"
@interface HXPhoto3DTouchViewController () {
    PHImageRequestID requestId;
}
@property (strong, nonatomic) PHLivePhotoView *livePhotoView;
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@end

@implementation HXPhoto3DTouchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.imageView.hx_size = self.model.previewViewSize;
    self.imageView.image = self.image;
    [self.view addSubview:self.imageView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    switch (self.model.type) {
        case HXPhotoModelMediaTypeVideo:
            [self loadVideo];
            break;
        case HXPhotoModelMediaTypeCameraVideo:
            [self loadVideo];
            break;
        case HXPhotoModelMediaTypePhotoGif:
            [self loadGifPhoto];
            break;
        case HXPhotoModelMediaTypeLivePhoto:
            [self loadLivePhoto];
            break;
        default:
            [self loadPhoto];
            break;
    } 
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[PHImageManager defaultManager] cancelImageRequest:requestId];
    [self.player pause];
    [self.player seekToTime:kCMTimeZero];
    self.playerLayer.player = nil;
    self.player = nil;
    [self.playerLayer removeFromSuperlayer];
    if (_livePhotoView) {
        [self.livePhotoView stopPlayback];
        [self.livePhotoView removeFromSuperview];
        self.livePhotoView.livePhoto = nil;
        self.livePhotoView = nil;
    }
    [self.view addSubview:self.imageView];
}

- (void)loadPhoto {
    if (self.model.type == HXPhotoModelMediaTypeCameraPhoto) {
        self.imageView.image = self.model.thumbPhoto;
        return;
    }
    __weak typeof(self) weakSelf = self;
    
    requestId = [HXPhotoTools fetchPhotoWithAsset:self.model.asset photoSize:CGSizeMake(self.model.previewViewSize.width * 1.5, self.model.previewViewSize.height * 1.5) completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        weakSelf.imageView.image = photo;
    }];
}

- (void)loadGifPhoto {
    __weak typeof(self) weakSelf = self;
    requestId = [HXPhotoTools FetchPhotoDataForPHAsset:self.model.asset completion:^(NSData *imageData, NSDictionary *info) {
        if (imageData) {
            UIImage *gifImage = [UIImage animatedGIFWithData:imageData];
            if (gifImage.images.count > 0) {
                weakSelf.imageView.image = nil;
                weakSelf.imageView.image = gifImage;
            }
        }
    }];
}

- (void)loadLivePhoto {
    if (self.model.isCloseLivePhoto) {
        [self loadPhoto];
        return;
    }
    self.livePhotoView = [[PHLivePhotoView alloc] initWithFrame:CGRectMake(0, 0, self.model.previewViewSize.width, self.model.previewViewSize.height)];
    self.livePhotoView.clipsToBounds = YES;
    self.livePhotoView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview:self.livePhotoView];
    __weak typeof(self) weakSelf = self;
    requestId = [HXPhotoTools FetchLivePhotoForPHAsset:self.model.asset Size:CGSizeMake(self.model.previewViewSize.width * 1.5, self.model.previewViewSize.height * 1.5) Completion:^(PHLivePhoto *livePhoto, NSDictionary *info) {
        weakSelf.livePhotoView.livePhoto = livePhoto;
        [weakSelf.livePhotoView startPlaybackWithStyle:PHLivePhotoViewPlaybackStyleHint];
        [weakSelf.imageView removeFromSuperview];
    }];
}

- (void)loadVideo {
    if (self.model.type == HXPhotoModelMediaTypeCameraVideo) {
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:self.model.videoURL];
        self.player = [AVPlayer playerWithPlayerItem:playerItem];
        [self playVideo];
    }else {
        __weak typeof(self) weakSelf = self;
//        requestId = [[PHImageManager defaultManager] requestAVAssetForVideo:self.model.asset options:nil resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
//            BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue]);
//            if (downloadFinined && asset) {
//                __strong typeof(weakSelf) strongSelf = self;
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    strongSelf.player = [AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithAsset:asset]];
//                    [strongSelf playVideo];
//                });
//            }
//        }];
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.deliveryMode = PHVideoRequestOptionsDeliveryModeFastFormat;
        options.networkAccessAllowed = NO;
        
        requestId = [[PHImageManager defaultManager] requestPlayerItemForVideo:self.model.asset options:options resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
            BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue]);
            if (downloadFinined && playerItem) {
                __strong typeof(weakSelf) strongSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    strongSelf.player = [AVPlayer playerWithPlayerItem:playerItem];
                    [strongSelf playVideo];
                });
            }
        }];
    }
}

- (void)playVideo {
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = CGRectMake(0, 0, self.model.previewViewSize.width, self.model.previewViewSize.height);
    [self.view.layer insertSublayer:self.playerLayer atIndex:0];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.player play];
        [self.imageView removeFromSuperview];
    });
}

//- (void)dealloc {
//
//}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        _imageView.clipsToBounds = YES;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.hx_x = 0;
        _imageView.hx_y = 0;
    }
    return _imageView;
}
//- (PHLivePhotoView *)livePhotoView {
//    if (!_livePhotoView) {
//        _livePhotoView = [[PHLivePhotoView alloc] init];
//        _livePhotoView.clipsToBounds = YES;
//        _livePhotoView.contentMode = UIViewContentModeScaleAspectFill;
//    }
//    return _livePhotoView;
//}
@end
