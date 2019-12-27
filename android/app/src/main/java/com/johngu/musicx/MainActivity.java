package com.johngu.musicx;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;

import androidx.annotation.NonNull;
import androidx.palette.graphics.Palette;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;
import wseemann.media.FFmpegMediaMetadataRetriever;

public class MainActivity extends FlutterActivity {
    static public MainActivity instance;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        final ThreadFactory threadFactory = r -> {
            final Thread thread = new Thread(r);
            thread.setPriority(Thread.MIN_PRIORITY);
            thread.setDaemon(true);
            thread.setName("MediaService For MediaPlayer Handler Thread");
            return thread;
        };
        final ThreadPoolExecutor threadPoolExecutor;
        threadPoolExecutor = new ThreadPoolExecutor(2,
                4, 1,
                TimeUnit.MINUTES,
                new LinkedBlockingQueue<>(),
                threadFactory,
                new ThreadPoolExecutor.DiscardOldestPolicy());

        Constants.NativeMethodChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                "Native");
        Constants.NativeMethodChannel.setMethodCallHandler((methodCall, result) -> {
            switch (methodCall.method) {
                case "Java":
                    Log.d("MethodChannel", "Accessible");
                    result.success("Dart");
                    break;

                case "Palette":
                    final int token = methodCall.argument("token");
                    final byte[] data = methodCall.argument("data");
                    assert data != null;
                    threadPoolExecutor.execute(new PaletteRunnable(data, token));
                    result.success(null);
                    break;

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
                    Log.d("getEmbeddedPicture", filePath);
                    FFmpegMediaMetadataRetriever mmr;
                    switch (methodCall.method) {
                        case "getEmbeddedPicture":
                            mmr = new FFmpegMediaMetadataRetriever();
                            mmr.setDataSource(filePath);
                            final byte[] res = mmr.getEmbeddedPicture();
                            result.success(res);
                            mmr.release();
                            break;

                        case "getBasicInfo":
                            mmr = new FFmpegMediaMetadataRetriever();
                            mmr.setDataSource(filePath);
                            final Map<String, String> info = new HashMap<String, String>() {{
                                put("title", mmr.extractMetadata(FFmpegMediaMetadataRetriever.METADATA_KEY_TITLE));
                                put("artist", mmr.extractMetadata(FFmpegMediaMetadataRetriever.METADATA_KEY_ARTIST));
                                put("album", mmr.extractMetadata(FFmpegMediaMetadataRetriever.METADATA_KEY_ALBUM));
                            }};
                            result.success(info);
                            mmr.release();
                            break;

                        default:
                            result.notImplemented();

                    }
                });
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        instance = this;
        Constants.MainThread = new Handler();
    }


    private static class PaletteRunnable implements Runnable {
        final byte[] data;
        final int token;

        PaletteRunnable(@NonNull final byte[] data, @NonNull final int token) {
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
                put("Vibrant", palette.getVibrantSwatch() != null ? palette.getVibrantSwatch().getRgb() : null);
                put("Muted", palette.getMutedSwatch() != null ? palette.getMutedSwatch().getRgb() : null);

                put("LightVibrant", palette.getLightVibrantSwatch() == null ? null : palette.getLightVibrantSwatch().getRgb());
                put("LightMuted", palette.getLightMutedSwatch() == null ? null : palette.getLightMutedSwatch().getRgb());
                put("DarkVibrant", palette.getDarkVibrantSwatch() == null ? null : palette.getDarkVibrantSwatch().getRgb());
                put("DarkMuted", palette.getDarkMutedSwatch() == null ? null : palette.getDarkMutedSwatch().getRgb());
            }};
            Constants.MainThread.post(() ->
                    Constants.MediaMetadataRetrieverMethodChannel.invokeMethod("Palette", info));
        }
    }


}
