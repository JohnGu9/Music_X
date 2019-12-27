package com.johngu.component;

import java.util.LinkedList;
import java.util.List;

// This package is singleThread Manager.
// Feature: run multi Runnable on SingleThread Sequentially
public final class AsyncTaskManager extends Thread {

    private final List<Runnable> tasks;
    private boolean _isRunning;

    public AsyncTaskManager() {
        tasks = new LinkedList<Runnable>();
        _isRunning = true;
        this.setDaemon(true);
        this.setName("AsyncTaskManager");
        this.start();
    }

    public synchronized void addTask(Runnable runnable) {
        tasks.add(runnable);
        this.notify();
    }

    public synchronized boolean isRunning() {
        return _isRunning;
    }

    private synchronized Runnable _removeTask() {
        return tasks.remove(0);
    }

    private synchronized void _waitTasks() {
        if (tasks.isEmpty()) {
            try {
                this.wait();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public void run() {
        while (_isRunning) {
            _waitTasks();
            final Runnable runnable = _removeTask();
            try {
                runnable.run();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

    }

    public synchronized void dispose() {
        _isRunning = false;
    }
}
