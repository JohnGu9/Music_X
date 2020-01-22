package com.johngu.music.Service;

import android.annotation.TargetApi;
import android.app.IntentService;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaMetadata;
import android.media.MediaPlayer;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.media.app.NotificationCompat.MediaStyle;

import com.johngu.music.Constants;
import com.johngu.music.MainActivity;
import com.johngu.music.R;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import wseemann.media.FFmpegMediaMetadataRetriever;

import static java.lang.Math.max;

public final class MediaService extends IntentService
        implements MediaPlayer.OnPreparedListener,
        MediaPlayer.OnCompletionListener,
        MediaPlayer.OnErrorListener,
        MediaPlayer.OnSeekCompleteListener,
        MediaPlayer.OnBufferingUpdateListener,
        AudioManager.OnAudioFocusChangeListener {


    final ThreadPoolExecutor threadPoolExecutor;


    public MediaService() {
        super("MediaService");
        threadPoolExecutor = new ThreadPoolExecutor(1,
                1, 10,
                TimeUnit.SECONDS,
                new LinkedBlockingQueue<>(),
                Constants.MIN_PRIORITY_ThreadFactory,
                new ThreadPoolExecutor.DiscardOldestPolicy());
        currentDataSource = new AtomicReference<>(null);
    }

    static final String ACTION_KEY_PLAY = "com.johngu.ACTION_KEY_PLAY";
    static final String ACTION_KEY_PAUSE = "com.johngu.ACTION_KEY_PAUSE";
    static final String ACTION_KEY_PREVIOUS = "com.johngu.ACTION_KEY_PREVIOUS";
    static final String ACTION_KEY_NEXT = "com.johngu.ACTION_KEY_NEXT";

    @Override
    protected void onHandleIntent(@Nullable Intent intent) {
        if (intent == null) {
            return;
        }

        final String action = intent.getAction();
        if (action == null) return;

        switch (action) {
            case ACTION_KEY_PLAY:
                Constants.MainThread.post(STARTRunnable);
                break;

            case ACTION_KEY_PAUSE:
            case AudioManager.ACTION_AUDIO_BECOMING_NOISY:
                Constants.MainThread.post(PAUSERunnable);
                break;

            case ACTION_KEY_PREVIOUS:
                Constants.MainThread.post(PREVIOUSRunnable);
                break;

            case ACTION_KEY_NEXT:
                Constants.MainThread.post(NEXTRunnable);
                break;

            case Intent.ACTION_SCREEN_ON:
                customNotificationManager.notifyThis(mediaPlayer.isPlaying());
                break;

            default:

        }
    }

    static final Runnable STARTRunnable = () -> Constants.MediaPlayerMethodChannel.invokeMethod("start", null);
    static final Runnable PAUSERunnable = () -> Constants.MediaPlayerMethodChannel.invokeMethod("pause", null);
    static final Runnable PREVIOUSRunnable = () -> Constants.MediaPlayerMethodChannel.invokeMethod("toPrevious", null);
    static final Runnable NEXTRunnable = () -> Constants.MediaPlayerMethodChannel.invokeMethod("toNext", null);

    @Override
    public IBinder onBind(Intent intent) {
        return new MediaServiceBinder();
    }

    public final class MediaServiceBinder extends Binder {
        public final void start() {
            MediaService.this.start();
        }

        public final void pause() {
            MediaService.this.pause();
        }

        public final void reset() {
            threadPoolExecutor.execute(new MediaPlayerRunnable(currentDataSource.get(), MediaPlayer_reset));
        }

        public final void setDataSource(final String filePath,
                                        final String title,
                                        final String artist,
                                        final String album,
                                        final String extendFilePath) {
            currentDataSource.set(filePath);
            customNotificationManager.setupNotification(title, artist, album, filePath, extendFilePath);
            threadPoolExecutor.execute(new MediaPlayerRunnable(currentDataSource.get(), MediaPlayer_reset));
            threadPoolExecutor.execute(new MediaPlayerRunnable(currentDataSource.get(), MediaPlayer_setDataSource));
        }

        public final int getCurrentPosition() {
            return mediaPlayer.getCurrentPosition();
        }

        public final int getDuration() {
            return mediaPlayer.getDuration();
        }

        public final void setLooping(final boolean loop) {
            mediaPlayer.setLooping(loop);
        }

        public final boolean isLooping() {
            return mediaPlayer.isLooping();
        }

        public final boolean isPlaying() {
            return mediaPlayer.isPlaying();
        }

        public final void seekTo(final int position) {
            threadPoolExecutor.execute(new MediaPlayerRunnable(currentDataSource.get(), new seekToRunnable(position)));
        }

        public final void setVolume(final float volume) {
            MediaService.this.volume = volume;
            mediaPlayer.setVolume(MediaService.this.volume, MediaService.this.volume);
        }

        public final float getVolume() {
            return MediaService.this.volume;
        }

        public final void turnOffNotification() {
            customNotificationManager.turnOff();
        }

        public final void turnOnNotification() {
            customNotificationManager.turnOn(mediaPlayer.isPlaying());
        }

    }

    private class seekToRunnable implements Runnable {
        final int position;

        seekToRunnable(final int position) {
            this.position = position;

        }

        @Override
        public void run() {
            final int state = playbackStateBuilder.build().getState();
            if (state == PlaybackStateCompat.STATE_CONNECTING) {
                MediaPlayer_prepare.run();
                mediaPlayer.seekTo(position);
            } else if (state == PlaybackStateCompat.STATE_PAUSED || state == PlaybackStateCompat.STATE_PLAYING) {
                mediaPlayer.seekTo(position);
            }
        }
    }

    final void start() {
        threadPoolExecutor.execute(new MediaPlayerRunnable(currentDataSource.get(), MediaPlayer_play));
    }

    final void pause() {
        threadPoolExecutor.execute(new MediaPlayerRunnable(currentDataSource.get(), MediaPlayer_pause));
    }

    private class MediaPlayerRunnable implements Runnable {
        final String DataSource;
        final Runnable sub;

        MediaPlayerRunnable(String dataSource, Runnable sub) {
            this.DataSource = dataSource;
            this.sub = sub;
        }

        @Override
        public final void run() {
            final String source = currentDataSource.get();
            if (source != null && !source.equals(DataSource)) return;
            sub.run();
        }
    }

    static private final float PLAYBACK_SPEED = 1.0f;
    static private final int INVALID_POSITION = 0;
    public final AtomicReference<String> currentDataSource;
    private MediaPlayer mediaPlayer;

    // Don't use it in other threads
    private MediaSessionCompat mediaSession;
    // Don't use it in other threads
    private PlaybackStateCompat.Builder playbackStateBuilder;

    final Runnable MediaPlayer_play = new Runnable() {
        @Override
        public final void run() {
            Log.d("MediaPlayer", "Play");
            if (playbackStateBuilder.build().getState() == PlaybackStateCompat.STATE_CONNECTING) {
                MediaPlayer_prepare.run();
                return;
            } else if (playbackStateBuilder.build().getState() != PlaybackStateCompat.STATE_PAUSED) {
                return;
            }

            int res = audioFocusRequest();
            if (res != AudioManager.AUDIOFOCUS_REQUEST_FAILED) {
                volumeTo(mediaPlayer, volume);
                mediaPlayer.start();
                if (mediaPlayer.isPlaying()) {
                    final Map<String, Object> result = new HashMap<String, Object>() {{
                        put("State", "started");
                        put("CurrentPosition", mediaPlayer.getCurrentPosition());
                        put("Duration", mediaPlayer.getDuration());
                    }};
                    Constants.MainThread.post(() -> Constants.MediaPlayerMethodChannel.invokeMethod("State", result));
                    playbackStateBuilder.setState(PlaybackStateCompat.STATE_PLAYING,
                            mediaPlayer.getCurrentPosition(),
                            PLAYBACK_SPEED);
                    mediaSession.setPlaybackState(playbackStateBuilder.build());
                    customNotificationManager.notifyThis(true);
                }
            }
        }
    };
    final Runnable MediaPlayer_pause = new Runnable() {
        @Override
        public final void run() {
            if (!mediaPlayer.isPlaying()) {
                return;
            }
            volumeTo(mediaPlayer, 0.f);
            mediaPlayer.pause();
            audioFocusRelease();
            final Map<String, Object> result = new HashMap<String, Object>() {{
                put("State", "paused");
                put("CurrentPosition", mediaPlayer.getCurrentPosition());
                put("Duration", mediaPlayer.getDuration());
            }};
            Constants.MainThread.post(() -> Constants.MediaPlayerMethodChannel.invokeMethod("State", result));
            playbackStateBuilder.setState(PlaybackStateCompat.STATE_PAUSED,
                    mediaPlayer.getCurrentPosition(),
                    PLAYBACK_SPEED);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
            customNotificationManager.notifyThis(false);
        }
    };
    final Runnable MediaPlayer_reset = new Runnable() {
        @Override
        public final void run() {
            mediaPlayer.reset();
            playbackStateBuilder.setState(PlaybackStateCompat.STATE_NONE,
                    INVALID_POSITION,
                    PLAYBACK_SPEED);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
            final Map<String, Object> result = new HashMap<String, Object>() {{
                put("State", "end");
            }};
            Constants.MainThread.post(() -> Constants.MediaPlayerMethodChannel.invokeMethod("State", result));

        }
    };
    final Runnable MediaPlayer_prepare = new Runnable() {
        @Override
        public final void run() {
            if ((playbackStateBuilder.build().getState() != PlaybackStateCompat.STATE_CONNECTING))
                throw new AssertionError();
            playbackStateBuilder.setState(PlaybackStateCompat.STATE_BUFFERING,
                    INVALID_POSITION,
                    PLAYBACK_SPEED);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
            try {
                mediaPlayer.prepare();
                playbackStateBuilder.setState(PlaybackStateCompat.STATE_PAUSED,
                        INVALID_POSITION,
                        PLAYBACK_SPEED);
                mediaSession.setPlaybackState(playbackStateBuilder.build());
            } catch (IOException e) {
                e.printStackTrace();
            }
            //onPreparedCallBack
        }
    };
    final Runnable MediaPlayer_setDataSource = new Runnable() {
        @Override
        public final void run() {
            try {
                playbackStateBuilder.setState(PlaybackStateCompat.STATE_CONNECTING,
                        INVALID_POSITION,
                        PLAYBACK_SPEED);
                mediaSession.setPlaybackState(playbackStateBuilder.build());
                final String source = currentDataSource.get();
                mediaPlayer.setDataSource(source);
                final Map<String, Object> result = new HashMap<String, Object>() {{
                    put("State", "paused");
                }};
                Constants.MainThread.post(() -> Constants.MediaPlayerMethodChannel.invokeMethod("State", result));
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    };

    private AudioAttributes audioAttributes;

    final void MediaPlayerInitialization() {
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK);
        mediaPlayer.setOnPreparedListener(this);
        mediaPlayer.setOnCompletionListener(this);
        mediaPlayer.setOnErrorListener(this);
        mediaPlayer.setOnBufferingUpdateListener(this);
        mediaPlayer.setOnSeekCompleteListener(this);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            audioAttributes = new AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setFlags(AudioAttributes.FLAG_LOW_LATENCY)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setLegacyStreamType(MainActivity.instance.getVolumeControlStream())
                    .build();
            mediaPlayer.setAudioAttributes(audioAttributes);
        }

        mediaPlayer.setAudioStreamType(MainActivity.instance.getVolumeControlStream());
        volume = 1.f;

        mediaSession = new MediaSessionCompat(this, "MediaPlayer");
        playbackStateBuilder = new PlaybackStateCompat.Builder();
        playbackStateBuilder
                .setState(PlaybackStateCompat.STATE_NONE, 0, PLAYBACK_SPEED)
        ;
        mediaSession.setPlaybackState(playbackStateBuilder.build());
        mediaSession.setActive(true);
    }

    private AudioManager audioManager;
    private AudioFocusRequest audioFocusRequest;

    private void AudioFocusInit() {
        audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);
        audioManager.setMode(AudioManager.MODE_NORMAL);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(audioAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setWillPauseWhenDucked(true)
                    .setOnAudioFocusChangeListener(this)
                    .build();
        }
    }

    private int audioFocusRequest() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.abandonAudioFocusRequest(audioFocusRequest);
            return audioManager.requestAudioFocus(audioFocusRequest);
        } else {
            audioManager.abandonAudioFocus(this);
            return audioManager.requestAudioFocus(this, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
        }
    }

    private void audioFocusRelease() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.abandonAudioFocusRequest(audioFocusRequest);
        } else {
            audioManager.abandonAudioFocus(this);
        }
    }

    private CustomNotificationManager customNotificationManager;

    private void notificationManagerInit() {
        customNotificationManager = new CustomNotificationManager(CustomNotificationManagerState.ON);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        MediaPlayerInitialization();
        AudioFocusInit();
        notificationManagerInit();
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        dispose();
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onDestroy() {
        dispose();
        super.onDestroy();
    }

    void dispose() {
        threadPoolExecutor.shutdownNow();
        customNotificationManager.cancel();
        playbackStateBuilder.setState(PlaybackStateCompat.STATE_NONE, 0, PLAYBACK_SPEED);
        mediaSession.setPlaybackState(playbackStateBuilder.build());
    }

    private boolean isPlayingBeforeLossFocus = false;
    private float volume;

    final void volumeTo(final MediaPlayer mp, final float newVolume) {
        mp.setVolume(newVolume, newVolume);
    }

    @Override
    final public void onAudioFocusChange(int focusChange) {
        switch (focusChange) {
            case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
            case AudioManager.AUDIOFOCUS_LOSS:
                if (mediaPlayer != null && mediaPlayer.isPlaying()) {
                    isPlayingBeforeLossFocus = true;
                    pause();
                } else {
                    isPlayingBeforeLossFocus = false;
                }
                break;

            case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
                volumeTo(mediaPlayer, (float) max(volume - 0.2, 0.0));
                break;

            case AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE:
            case AudioManager.AUDIOFOCUS_GAIN_TRANSIENT:
            case AudioManager.AUDIOFOCUS_GAIN:
                Log.d("AUDIOFOCUS_GAIN: ", "focusChange");
                if (volume >= 0) {
                    volumeTo(mediaPlayer, volume);
                }
                if (mediaPlayer != null && !mediaPlayer.isPlaying() && isPlayingBeforeLossFocus) {
                    start();
                }
                // clear flag
                isPlayingBeforeLossFocus = false;
                break;
        }
    }

    @Override
    public void onBufferingUpdate(MediaPlayer mp, int percent) {
        Constants.MediaPlayerMethodChannel.invokeMethod("onBufferingUpdate", null);
    }

    @Override
    public void onCompletion(MediaPlayer mp) {
        Constants.MediaPlayerMethodChannel.invokeMethod("onCompletion", null);
    }

    @Override
    public boolean onError(MediaPlayer mp, int what, int extra) {
        Constants.MediaPlayerMethodChannel.invokeMethod("onError", null);
        return false;
    }

    @Override
    public void onPrepared(MediaPlayer mp) {
        threadPoolExecutor.execute(new MediaPlayerRunnable(currentDataSource.get(), MediaPlayer_play));
    }

    @Override
    public void onSeekComplete(MediaPlayer mp) {
        if (mediaPlayer.isPlaying()) {
            final Map<String, Object> result = new HashMap<String, Object>() {{
                put("CurrentPosition", mediaPlayer.getCurrentPosition());
                put("Duration", mediaPlayer.getDuration());
                put("State", "started");
            }};
            Constants.MediaPlayerMethodChannel.invokeMethod("onSeekComplete", result);
        } else {
            final Map<String, Object> result = new HashMap<String, Object>() {{
                put("CurrentPosition", mediaPlayer.getCurrentPosition());
                put("Duration", mediaPlayer.getDuration());
                put("State", "paused");
            }};
            Constants.MediaPlayerMethodChannel.invokeMethod("onSeekComplete", result);
        }
    }

    static final String MediaPlayerNotificationChannel_ID = "MediaPlayer";
    static final CharSequence MediaPlayerNotificationChannel_NAME = "Playback";
    static final String MediaPlayerNotificationChannel_DESCRIPTION = "MediaPlayer notification for playback control";
    static final int MediaPlayerNotifyID = 0;

    enum CustomNotificationManagerState {
        ON, OFF
    }

    private class CustomNotificationManager {

        final private NotificationManager notificationManager;
        final private MediaMetadataCompat.Builder mediaMetadata;
        final private NotificationCompat.Builder notificationPendingBuilder;
        final private NotificationCompat.Builder notificationActingBuilder;

        CustomNotificationManagerState state;

        public final void turnOn(final boolean isPlaying) {
            state = CustomNotificationManagerState.ON;
            mediaSession.setActive(true);
            notifyThis(isPlaying);
        }

        public final void turnOff() {
            state = CustomNotificationManagerState.OFF;
            mediaSession.setActive(false);
            cancel();
        }

        NotificationManager getNotificationManager() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return getSystemService(NotificationManager.class);
            } else {
                return (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            }
        }

        CustomNotificationManager(CustomNotificationManagerState state) {
            this.state = state;
            notificationManager = getNotificationManager();
            assert notificationManager != null;

            mediaMetadata = new MediaMetadataCompat.Builder();
            mediaSession.setMetadata(mediaMetadata.build());

            mediaSession.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS |
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS |
                    MediaSessionCompat.FLAG_HANDLES_QUEUE_COMMANDS);
            mediaSession.setCallback(new MediaSessionCompat.Callback() {
                @Override
                final public void onPlay() {
                    super.onPlay();
                    Constants.MainThread.post(STARTRunnable);
                }

                @Override
                final public void onPause() {
                    super.onPause();
                    Constants.MainThread.post(PAUSERunnable);
                }

                @Override
                final public void onSkipToNext() {
                    super.onSkipToNext();
                    Constants.MainThread.post(NEXTRunnable);
                }

                @Override
                final public void onSkipToPrevious() {
                    super.onSkipToPrevious();
                    Constants.MainThread.post(PREVIOUSRunnable);
                }


                @TargetApi(Build.VERSION_CODES.N)
                @Override
                final public void onSeekTo(long pos) {
                    mediaPlayer.seekTo(Math.toIntExact(pos));
                    super.onSeekTo(pos);
                }
            });
            playbackStateBuilder
                    .setActions(PlaybackStateCompat.ACTION_SEEK_TO
                            | PlaybackStateCompat.ACTION_PLAY
                            | PlaybackStateCompat.ACTION_PAUSE
                            | PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
                            | PlaybackStateCompat.ACTION_SKIP_TO_NEXT);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
            mediaSession.setActive(true);

            final MediaStyle mediaStyle = new MediaStyle().setShowActionsInCompactView(1, 2).setMediaSession(mediaSession.getSessionToken());
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                final int MediaPlayerNotificationChannel_IMPORTANT = android.app.NotificationManager.IMPORTANCE_DEFAULT;
                final NotificationChannel channel = new NotificationChannel(
                        MediaPlayerNotificationChannel_ID,
                        MediaPlayerNotificationChannel_NAME,
                        MediaPlayerNotificationChannel_IMPORTANT);
                channel.setDescription(MediaPlayerNotificationChannel_DESCRIPTION);
                channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
                channel.setSound(null, null);
                notificationManager.deleteNotificationChannel(MediaPlayerNotificationChannel_ID);
                notificationManager.createNotificationChannel(channel);
            }
            final PendingIntent contentIntent = PendingIntent.getActivity(getApplicationContext(),
                    0,
                    new Intent(MediaService.this, MainActivity.class),
                    PendingIntent.FLAG_UPDATE_CURRENT);
            notificationPendingBuilder = new NotificationCompat.Builder(getApplicationContext(), MediaPlayerNotificationChannel_ID)
                    .setSmallIcon(R.drawable.ic_music)
                    .setContentIntent(contentIntent)
                    .setContentTitle("Playback")
                    .setSound(null)
                    .setOngoing(false)
                    .setShowWhen(false)
                    .setStyle(mediaStyle)
                    .setPriority(Notification.PRIORITY_DEFAULT)
                    .addAction(generateMediaServiceAction(R.drawable.ic_previous, "Previous", ACTION_KEY_PREVIOUS))
                    .addAction(generateMediaServiceAction(R.drawable.ic_play, "Play", ACTION_KEY_PLAY))
                    .addAction(generateMediaServiceAction(R.drawable.ic_next, "Next", ACTION_KEY_NEXT));

            notificationActingBuilder = new NotificationCompat.Builder(getApplicationContext(), MediaPlayerNotificationChannel_ID)
                    .setSmallIcon(R.drawable.ic_music)
                    .setContentIntent(contentIntent)
                    .setContentTitle("Playback")
                    .setSound(null)
                    .setOngoing(true)
                    .setShowWhen(false)
                    .setStyle(mediaStyle)
                    .setPriority(Notification.PRIORITY_DEFAULT)
                    .addAction(generateMediaServiceAction(R.drawable.ic_previous, "Previous", ACTION_KEY_PREVIOUS))
                    .addAction(generateMediaServiceAction(R.drawable.ic_pause, "Pause", ACTION_KEY_PAUSE))
                    .addAction(generateMediaServiceAction(R.drawable.ic_next, "Next", ACTION_KEY_NEXT));

            notificationManager.cancel(MediaPlayerNotifyID);
        }

        private NotificationCompat.Action generateMediaServiceAction(final int icon, final String title, final String extra) {
            final Intent intent = new Intent(getApplicationContext(), MediaService.class)
                    .setAction(extra)
                    .setFlags(Intent.FLAG_ACTIVITY_FORWARD_RESULT);
            final PendingIntent pendingIntent = PendingIntent.getService(getApplicationContext(), 0, intent, PendingIntent.FLAG_UPDATE_CURRENT);
            return new NotificationCompat.Action.Builder(icon, title, pendingIntent).build();
        }

        final void setupNotification(
                final String title,
                final String artist,
                final String album,
                final String filePath,
                final String extendFilePath) {
            threadPoolExecutor.execute(new setupNotificationRunnable(title, artist, album, filePath, extendFilePath));
        }

        final void notifyThis(final boolean isPlaying) {
            if (state == CustomNotificationManagerState.ON) {
                if (isPlaying) {
                    notificationManager.notify(MediaPlayerNotifyID, notificationActingBuilder.build());
                } else {
                    notificationManager.notify(MediaPlayerNotifyID, notificationPendingBuilder.build());
                }
            }
        }

        final void cancel() {
            notificationManager.cancel(MediaPlayerNotifyID);
        }

        final void cancelNow() {
            if (!threadPoolExecutor.isShutdown() || !threadPoolExecutor.isTerminating() || !threadPoolExecutor.isTerminated()) {
                throw new IllegalStateException("threadPoolExecutor is running");
            }
            notificationManager.cancel(MediaPlayerNotifyID);
        }

        private class setupNotificationRunnable implements Runnable {
            final String title;
            final String artist;
            final String album;
            final String filePath;
            final String extendFilePath;


            setupNotificationRunnable(
                    final String title,
                    final String artist,
                    final String album,
                    final String filePath,
                    final String extendFilePath) {
                this.title = title;
                this.album = album;
                this.artist = artist;
                this.filePath = filePath;
                this.extendFilePath = extendFilePath;

            }

            @Override
            public void run() {
                if (!currentDataSource.get().equals(filePath)) return;
                final FFmpegMediaMetadataRetriever mmr = new FFmpegMediaMetadataRetriever();
                final BitmapFactory.Options options = new BitmapFactory.Options();
                final Bitmap bitmap;

                mmr.setDataSource(filePath);
                final byte[] bytes = mmr.getEmbeddedPicture();
                if (bytes != null) {
                    options.inJustDecodeBounds = true;
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
                    options.inSampleSize = Constants.calculateInSampleSize(options, 512, 512);
                    options.inJustDecodeBounds = false;
                    bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
                } else {
                    options.inSampleSize = 4;
                    bitmap = BitmapFactory.decodeResource(getResources(), R.drawable.ic_abstract, options);
                }

                notificationPendingBuilder.setContentTitle(title);
                notificationPendingBuilder.setContentText(artist);
                notificationPendingBuilder.setSubText(album);

                notificationActingBuilder.setContentTitle(title);
                notificationActingBuilder.setContentText(artist);
                notificationActingBuilder.setSubText(album);

                notificationPendingBuilder.setLargeIcon(bitmap);
                notificationActingBuilder.setLargeIcon(bitmap);

                mediaMetadata.putBitmap(MediaMetadata.METADATA_KEY_ART, bitmap);
                mediaMetadata.putString(MediaMetadata.METADATA_KEY_TITLE, title);
                mediaMetadata.putString(MediaMetadata.METADATA_KEY_ARTIST, artist);
                mediaMetadata.putString(MediaMetadata.METADATA_KEY_ALBUM, album);
                mediaMetadata.putLong(MediaMetadata.METADATA_KEY_DURATION, Integer.parseInt(mmr.extractMetadata(FFmpegMediaMetadataRetriever.METADATA_KEY_DURATION)));
                mediaSession.setMetadata(mediaMetadata.build());

                notifyThis(mediaPlayer.isPlaying());
                mmr.release();
            }
        }
    }
}
