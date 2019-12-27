package com.johngu.musicx.Service;

import android.annotation.TargetApi;
import android.app.IntentService;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;

import androidx.annotation.Nullable;

import com.johngu.musicx.MainActivity;

import java.io.IOException;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

public final class MediaService extends IntentService
        implements MediaPlayer.OnPreparedListener,
        MediaPlayer.OnCompletionListener,
        MediaPlayer.OnErrorListener,
        MediaPlayer.OnSeekCompleteListener,
        MediaPlayer.OnBufferingUpdateListener,
        AudioManager.OnAudioFocusChangeListener {
    static final String ACTION_MEDIAPLAYER = "com.johngu.MediaPlayer";

    final ThreadFactory threadFactoryForMediaplayer = r -> {
        final Thread thread = new Thread(r);
        thread.setPriority(Thread.MIN_PRIORITY);
        thread.setDaemon(true);
        thread.setName("MediaService For MediaPlayer Handler Thread");
        return thread;
    };
    final ThreadPoolExecutor threadPoolExecutorForMediaplayer;


    public MediaService() {
        super("MediaService");
        threadPoolExecutorForMediaplayer = new ThreadPoolExecutor(1,
                1, 1L,
                TimeUnit.MINUTES,
                new LinkedBlockingQueue<Runnable>(),
                threadFactoryForMediaplayer,
                new ThreadPoolExecutor.DiscardOldestPolicy());
    }

    @Override
    protected void onHandleIntent(@Nullable Intent intent) {
        final String action;
        if (intent != null) {
            action = intent.getAction();
            if (action == null) return;
            if (ACTION_MEDIAPLAYER.equals(action)) {
            }
        }

    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return super.onBind(intent);
    }

    static private class MediaPlayerRunnable implements Runnable {
        final String DataSource;
        final Runnable sub;

        MediaPlayerRunnable(String dataSource, Runnable sub) {
            this.DataSource = dataSource;
            this.sub = sub;
        }

        @Override
        public void run() {
            if (!currentDataSource.equals(DataSource)) return;
            sub.run();
        }
    }

    static private final float PLAYBACK_SPEED = 1.0f;
    static private final int INVALID_POSTION = 0;
    static public String currentDataSource;
    private MediaPlayer mediaPlayer;
    private MediaSessionCompat mediaSession;
    private PlaybackStateCompat.Builder playbackStateBuilder;

    final Runnable MediaPlayer_player = new Runnable() {
        @Override
        public void run() {
            mediaPlayer.start();
            playbackStateBuilder.setState(PlaybackStateCompat.STATE_PLAYING,
                    mediaPlayer.getCurrentPosition(),
                    PLAYBACK_SPEED);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
        }
    };
    final Runnable MediaPlayer_pause = new Runnable() {
        @Override
        public void run() {
            mediaPlayer.pause();
            playbackStateBuilder.setState(PlaybackStateCompat.STATE_PAUSED,
                    mediaPlayer.getCurrentPosition(),
                    PLAYBACK_SPEED);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
        }
    };
    final Runnable MediaPlayer_reset = new Runnable() {
        @Override
        public void run() {
            mediaPlayer.reset();
            playbackStateBuilder.setState(PlaybackStateCompat.STATE_NONE,
                    INVALID_POSTION,
                    PLAYBACK_SPEED);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
        }
    };
    final Runnable MediaPlayer_prepare = new Runnable() {
        @Override
        public void run() {
            playbackStateBuilder.setState(PlaybackStateCompat.STATE_BUFFERING,
                    INVALID_POSTION,
                    PLAYBACK_SPEED);
            mediaSession.setPlaybackState(playbackStateBuilder.build());
            try {
                mediaPlayer.prepare();
                playbackStateBuilder.setState(PlaybackStateCompat.STATE_PAUSED,
                        INVALID_POSTION,
                        PLAYBACK_SPEED);
                mediaSession.setPlaybackState(playbackStateBuilder.build());
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    };
    final Runnable MediaPlayer_seekTo = new Runnable() {
        @Override
        public void run() {
            if (mediaPlayer.isPlaying()) {
                playbackStateBuilder.setState(PlaybackStateCompat.STATE_PLAYING,
                        INVALID_POSTION,
                        PLAYBACK_SPEED);
                mediaSession.setPlaybackState(playbackStateBuilder.build());
            } else {
                playbackStateBuilder.setState(PlaybackStateCompat.STATE_PAUSED,
                        INVALID_POSTION,
                        PLAYBACK_SPEED);
                mediaSession.setPlaybackState(playbackStateBuilder.build());
            }

        }
    };

    void MediaPlayerInitialization() {
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setWakeMode(MainActivity.instance, PowerManager.PARTIAL_WAKE_LOCK);
        mediaPlayer.setOnPreparedListener(this);
        mediaPlayer.setOnCompletionListener(this);
        mediaPlayer.setOnErrorListener(this);
        mediaPlayer.setOnBufferingUpdateListener(this);
        mediaPlayer.setOnSeekCompleteListener(this);
        final AudioAttributes audioAttributes = new AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .setFlags(AudioAttributes.FLAG_LOW_LATENCY)
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setLegacyStreamType(MainActivity.instance.getVolumeControlStream())
                .build();
        mediaPlayer.setAudioAttributes(audioAttributes);
        mediaPlayer.setAudioStreamType(MainActivity.instance.getVolumeControlStream());

        mediaSession = new MediaSessionCompat(this, "MediaPlayer");
        mediaSession.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS | MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS);
        final MediaSessionCompat.Callback mediaSessionCallBack = new MediaSessionCompat.Callback() {
            @TargetApi(Build.VERSION_CODES.N)
            @Override
            public void onSeekTo(long pos) {
                mediaPlayer.seekTo(Math.toIntExact(pos));
                super.onSeekTo(pos);
            }
        };
        mediaSession.setCallback(mediaSessionCallBack);
        playbackStateBuilder = new PlaybackStateCompat.Builder();
        playbackStateBuilder
                .setState(PlaybackStateCompat.STATE_NONE, 0, PLAYBACK_SPEED)
                .setActions(PlaybackStateCompat.ACTION_SEEK_TO
                        | PlaybackStateCompat.ACTION_PLAY
                        | PlaybackStateCompat.ACTION_PAUSE
                        | PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
                        | PlaybackStateCompat.ACTION_SKIP_TO_NEXT);
        mediaSession.setPlaybackState(playbackStateBuilder.build());
        mediaSession.setActive(true);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        MediaPlayerInitialization();
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }

    @Override
    public void onAudioFocusChange(int focusChange) {

    }

    @Override
    public void onBufferingUpdate(MediaPlayer mp, int percent) {

    }

    @Override
    public void onCompletion(MediaPlayer mp) {

    }

    @Override
    public boolean onError(MediaPlayer mp, int what, int extra) {
        return false;
    }

    @Override
    public void onPrepared(MediaPlayer mp) {

    }

    @Override
    public void onSeekComplete(MediaPlayer mp) {

    }
}
