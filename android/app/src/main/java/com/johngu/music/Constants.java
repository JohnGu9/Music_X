package com.johngu.music;

import android.graphics.BitmapFactory;
import android.os.Handler;

import java.util.concurrent.ThreadFactory;

import io.flutter.plugin.common.MethodChannel;

public final class Constants {
    static MethodChannel NativeMethodChannel;
    static MethodChannel MediaMetadataRetrieverMethodChannel;
    static public MethodChannel MediaPlayerMethodChannel;

    static public Handler MainThread;

    static public final ThreadFactory MIN_PRIORITY_ThreadFactory = (final Runnable r) -> {
        final Thread thread = new Thread(r);
        thread.setPriority(Thread.MIN_PRIORITY);
        thread.setDaemon(true);
        thread.setName("MIN_PRIORITY_ThreadFactory");
        return thread;
    };

    public static int calculateInSampleSize(
            BitmapFactory.Options options, int reqWidth, int reqHeight) {
        // Raw height and width of image
        final int height = options.outHeight;
        final int width = options.outWidth;
        int inSampleSize = 1;

        if (height > reqHeight || width > reqWidth) {

            final int halfHeight = height / 2;
            final int halfWidth = width / 2;

            // Calculate the largest inSampleSize value that is a power of 2 and keeps both
            // height and width larger than the requested height and width.
            while ((halfHeight / inSampleSize) >= reqHeight
                    && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2;
            }
        }

        return inSampleSize;
    }
}
