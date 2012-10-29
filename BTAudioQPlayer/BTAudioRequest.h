//
//  AudioRequest.h
//

#import <Foundation/Foundation.h>

@protocol BTAudioRequestDelegate;
@interface BTAudioRequest : NSObject<NSURLConnectionDataDelegate> {
	NSURLConnection *_connection;
  NSMutableURLRequest *_request;
  NSInteger _contentLength;
  NSInteger _dataReceivedLength;
  float _lastProgress;
	id<BTAudioRequestDelegate> _delegate;
}

@property (nonatomic, assign) id<BTAudioRequestDelegate> delegate;

- (id)initRequestWithURL:(NSURL *)url delegate:(id<BTAudioRequestDelegate>)delegate;
- (void)setRequestRange:(NSInteger)start end:(NSInteger)end;
- (void)start;
/*
 * Cancels the request, guaranteeing that no further delegate messages will be sent.
 */
- (void)cancel;
@end

@protocol BTAudioRequestDelegate<NSObject>

- (void)audioRequestDidStart:(BTAudioRequest *)request;

- (void)audioRequestDidConnectOK:(BTAudioRequest *)request contentLength:(NSInteger)contentLength;
/*
 * Notifies the delegate when we've received bytes from the network.
 */
- (void)audioRequest:(BTAudioRequest *)request didReceiveData:(NSData *)data;
- (void)audioRequest:(BTAudioRequest *)request downloadProgress:(float)progress;
/*
 * Notifies the delegate when there are no more bytes to deliver.
 */
- (void)audioRequestDidFinish:(BTAudioRequest *)request;

- (void)audioRequest:(BTAudioRequest *)request didFailWithError:(NSError*)error;

@end
