package com.johngu.music;

import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;

import androidx.annotation.NonNull;
import androidx.palette.graphics.Palette;

import com.johngu.music.Service.MediaService;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    static public MainActivity instance;
    MediaService.MediaServiceBinder mediaServiceBinder;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);


        final ThreadPoolExecutor threadPoolExecutor =
                new ThreadPoolExecutor(2,
                        4, 1,
                        TimeUnit.MINUTES,
                        new LinkedBlockingQueue<>(),
                        Constants.MIN_PRIORITY_ThreadFactory,
                        new ThreadPoolExecutor.DiscardOldestPolicy());

        Constants.NativeMethodChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                "Native");
        Constants.NativeMethodChannel.setMethodCallHandler(
                (final MethodCall methodCall, final MethodChannel.Result result) -> {
                    switch (methodCall.method) {
                        case "Java":
                            Log.d("MethodChannel", "Accessible");
                            result.success("Dart");
                            return;

                        case "moveTaskToBack":
                            moveTaskToBack(true);
                            result.success(null);
                            return;

                        case "Palette":
                            final int token = methodCall.argument("token");
                            final byte[] data = methodCall.argument("data");
                            threadPoolExecutor.execute(new PaletteRunnable(data, token));
                            result.success(null);
                            return;

                        default:
                            result.notImplemented();
                    }
                });

        Constants.MediaMetadataRetrieverMethodChannel =
                new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                        "MediaMetadataRetriever");
        Constants.MediaMetadataRetrieverMethodChannel.setMethodCallHandler(
                (final MethodCall methodCall, final MethodChannel.Result result) -> {
                    final String filePath = methodCall.argument("filePath");
                    MediaMetadataRetriever mmr;
                    switch (methodCall.method) {
                        case "getEmbeddedPicture":
                            mmr = new MediaMetadataRetriever();
                            mmr.setDataSource(filePath);
                            result.success(mmr.getEmbeddedPicture());
                            mmr.release();
                            return;

                        case "getBasicInfo":
                            mmr = new MediaMetadataRetriever();
                            mmr.setDataSource(filePath);
                            final Map<String, String> info = new HashMap<String, String>() {{
                                put("title", mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE));
                                put("artist", mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST));
                                put("album", mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM));
                            }};
                            result.success(info);
                            mmr.release();
                            return;

                        default:
                            result.notImplemented();

                    }
                });


        Constants.MediaPlayerMethodChannel =
                new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "MediaPlayer");
        Constants.MediaPlayerMethodChannel.setMethodCallHandler(
                this::MediaPlayerMethodCall);

    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        instance = this;
        Constants.MainThread = new Handler();
    }


    private void MediaPlayerMethodCall(MethodCall methodCall, MethodChannel.Result result) {
        switch (methodCall.method) {
            case "init":
                // Init Service
                final Intent mediaServiceIntent = new Intent(this, MediaService.class);
                final ServiceConnection mediaServiceConnection = new ServiceConnection() {
                    @Override
                    public final void onServiceConnected(ComponentName name, IBinder service) {
                        mediaServiceBinder = (MediaService.MediaServiceBinder) service;
                    }

                    @Override
                    public final void onServiceDisconnected(ComponentName name) {
                        android.util.Log.d("MediaPlayerService", "onServiceDisconnected");
                        mediaServiceBinder = null;
                    }
                };
                bindService(mediaServiceIntent, mediaServiceConnection, BIND_AUTO_CREATE);
                break;
            case "start":
                mediaServiceBinder.start();
                break;
            case "pause":
                mediaServiceBinder.pause();
                break;
            case "reset":
                mediaServiceBinder.reset();
                break;
            case "setDataSource":
                mediaServiceBinder.setDataSource(methodCall.argument("filePath"),
                        methodCall.argument("title"),
                        methodCall.argument("artist"),
                        methodCall.argument("album"),
                        methodCall.argument("extendFilePath"));
                break;
            case "seekTo":
                mediaServiceBinder.seekTo(methodCall.argument("position"));
                break;
            case "setLooping":
                mediaServiceBinder.setLooping(methodCall.argument("loop"));
                break;
            case "turnOffNotification":
                mediaServiceBinder.turnOffNotification();
                break;
            case "turnOnNotification":
                mediaServiceBinder.turnOnNotification();
                break;
            case "setVolume":
                final float volume = (float)((double)methodCall.argument("volume")) ;
                mediaServiceBinder.setVolume(volume);
                break;
            case "getVolume":
                result.success(mediaServiceBinder.getVolume());
                return;
            case "getCurrentPosition":
                result.success(mediaServiceBinder.getCurrentPosition());
                return;
            case "getDuration":
                result.success(mediaServiceBinder.getDuration());
                return;
            case "isLooping":
                result.success(mediaServiceBinder.isLooping());
                return;
            case "isPlaying":
                result.success(mediaServiceBinder.isPlaying());
                return;
            default:
                result.notImplemented();
                return;

        }
        result.success(null);
    }


    private static class PaletteRunnable implements Runnable {
        final byte[] data;
        final int token;

        PaletteRunnable(@NonNull final byte[] data, final int token) {
            this.data = data;
            this.token = token;
        }

        @Override
        public void run() {
            final Bitmap bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
            final Palette palette = new Palette.Builder(bitmap).generate();
            final Map<String, Object> info = new HashMap<String, Object>() {{
                put("token", token);

                put("Dominant", palette.getDominantSwatch() != null ? palette.getDominantSwatch().getRgb() : null);
                put("DominantTitleText", palette.getDominantSwatch() != null ? palette.getDominantSwatch().getTitleTextColor() : null);
                put("Vibrant", palette.getVibrantSwatch() != null ? palette.getVibrantSwatch().getRgb() : null);
                put("VibrantTitleText", palette.getVibrantSwatch() != null ? palette.getVibrantSwatch().getTitleTextColor() : null);
                put("Muted", palette.getMutedSwatch() != null ? palette.getMutedSwatch().getRgb() : null);
                put("MutedTitleText", palette.getMutedSwatch() != null ? palette.getMutedSwatch().getTitleTextColor() : null);

                put("LightVibrant", palette.getLightVibrantSwatch() == null ? null : palette.getLightVibrantSwatch().getRgb());
                put("LightMuted", palette.getLightMutedSwatch() == null ? null : palette.getLightMutedSwatch().getRgb());
                put("DarkVibrant", palette.getDarkVibrantSwatch() == null ? null : palette.getDarkVibrantSwatch().getRgb());
                put("DarkMuted", palette.getDarkMutedSwatch() == null ? null : palette.getDarkMutedSwatch().getRgb());
            }};
            Constants.MainThread.post(() ->
                    Constants.NativeMethodChannel.invokeMethod("Palette", info));
        }
    }

}
