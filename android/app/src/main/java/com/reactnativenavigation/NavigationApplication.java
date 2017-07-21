package com.reactnativenavigation;

import android.app.Application;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.support.annotation.Nullable;
import android.support.v4.app.ActivityOptionsCompat;
import android.util.Log;
import com.facebook.react.ReactApplication;
import com.facebook.react.ReactNativeHost;
import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.ReactContext;
import com.reactnativenavigation.bridge.EventEmitter;
import com.reactnativenavigation.controllers.ActivityCallbacks;
import com.reactnativenavigation.react.NavigationReactGateway;
import com.reactnativenavigation.react.ReactGateway;

import java.util.LinkedList;
import java.util.List;
import java.util.Queue;

public abstract class NavigationApplication extends Application implements ReactApplication {

    public static NavigationApplication instance;

    private NavigationReactGateway reactGateway;
    private EventEmitter eventEmitter;
    private Handler handler;
    private ActivityCallbacks activityCallbacks;
    private Queue<Runnable> runAfterReactContextInitialized = new LinkedList<>();
    private boolean restartingApp = false;

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        handler = new Handler(getMainLooper());
        reactGateway = new NavigationReactGateway();
        eventEmitter = new EventEmitter(reactGateway);
        activityCallbacks = new ActivityCallbacks();
    }

    @Override
    public void startActivity(Intent intent) {
        String animationType = intent.getStringExtra("animationType");
        if (animationType != null && animationType.equals("fade")) {
            Bundle bundle = ActivityOptionsCompat.makeCustomAnimation(getApplicationContext(),
                    android.R.anim.fade_in,
                    android.R.anim.fade_out
            ).toBundle();
            super.startActivity(intent, bundle);
        } else {
            super.startActivity(intent);
        }
    }

    public void startReactContextOnceInBackgroundAndExecuteJS() {
        reactGateway.startReactContextOnceInBackgroundAndExecuteJS();
    }

    public void runOnMainThread(Runnable runnable) {
        handler.post(runnable);
    }

    public void runOnMainThread(Runnable runnable, long delay) {
        handler.postDelayed(runnable, delay);
    }

    public ReactGateway getReactGateway() {
        return reactGateway;
    }

    public ActivityCallbacks getActivityCallbacks() {
        return activityCallbacks;
    }

    protected void setActivityCallbacks(ActivityCallbacks activityLifecycleCallbacks) {
        this.activityCallbacks = activityLifecycleCallbacks;
    }

    public void setRestartingApp(boolean restartingApp) {
        this.restartingApp = restartingApp;
    }

    public boolean isRestartingApp() {
        return restartingApp;
    }

    public void addRunAfterReactContextInitialized(@Nullable Runnable runAfterReactContextInitialized) {
        this.runAfterReactContextInitialized.add(runAfterReactContextInitialized);
        Log.w("ReactNativeNavigation", "Adding new task to queue");
    }

    public boolean isReactContextInitialized() {
        return reactGateway.isInitialized();
    }

    public void onReactInitialized(ReactContext reactContext) {
        while (!runAfterReactContextInitialized.isEmpty()) {
            Log.w("ReactNativeNavigation", "Running task");
            runOnMainThread(runAfterReactContextInitialized.remove(), 300);
        }
        Log.w("ReactNativeNavigation", "Task list is now empty");
    }

    @Override
    public ReactNativeHost getReactNativeHost() {
        return reactGateway.getReactNativeHost();
    }

    public EventEmitter getEventEmitter() {
        return eventEmitter;
    }

    /**
     * @see ReactNativeHost#getJSMainModuleName()
     */
    @Nullable
    public String getJSMainModuleName() {
        return null;
    }

    /**
     * @see ReactNativeHost#getJSBundleFile()
     */
    @Nullable
    public String getJSBundleFile() {
        return null;
    }

    /**
     * @see ReactNativeHost#getBundleAssetName()
     */
    @Nullable
    public String getBundleAssetName() {
        return null;
    }

    public abstract boolean isDebug();

    @Nullable
    public abstract List<ReactPackage> createAdditionalReactPackages();
}
