package com.smartbusinesspro.shopkeeper;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public final class MainActivity extends Activity {
    private static final String HOST = "smartdigitalseva05-hash.github.io";
    private static final String ENTRY = "https://smartdigitalseva05-hash.github.io/smart-grocery-store-pro/shopkeeper.html";
    private WebView web;
    private LinearLayout splash;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(0xFF101827);
        getWindow().setNavigationBarColor(0xFF101827);

        FrameLayout root = new FrameLayout(this);
        splash = new LinearLayout(this);
        splash.setOrientation(LinearLayout.VERTICAL);
        splash.setGravity(Gravity.CENTER);
        splash.setPadding(24, 28, 24, 28);
        splash.setBackgroundColor(0xFFFFFFFF);

        ImageView mark = new ImageView(this);
        mark.setImageResource(R.drawable.brand_mark);
        mark.setScaleType(ImageView.ScaleType.FIT_CENTER);
        LinearLayout.LayoutParams markParams = new LinearLayout.LayoutParams(124, 124);
        markParams.bottomMargin = 18;
        splash.addView(mark, markParams);

        TextView brand = new TextView(this);
        brand.setText("SMART BUSINESS PRO");
        brand.setTextColor(0xFF10285D);
        brand.setTextSize(25);
        brand.setGravity(Gravity.CENTER);
        brand.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        splash.addView(brand, new LinearLayout.LayoutParams(-1, -2));

        TextView tagline = new TextView(this);
        tagline.setText("Every Business, One Smart Platform");
        tagline.setTextColor(0xFF174A9A);
        tagline.setTextSize(15);
        tagline.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams taglineParams = new LinearLayout.LayoutParams(-1, -2);
        taglineParams.topMargin = 10;
        splash.addView(tagline, taglineParams);

        TextView promise = new TextView(this);
        promise.setText("Discover Local Shops  •  Shop Smart\nConnect Easily  •  Grow Together");
        promise.setTextColor(0xFF10285D);
        promise.setTextSize(14);
        promise.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams promiseParams = new LinearLayout.LayoutParams(-1, -2);
        promiseParams.topMargin = 22;
        splash.addView(promise, promiseParams);

        TextView loading = new TextView(this);
        loading.setText("Loading your secure workspace…");
        loading.setTextColor(0xFF64748B);
        loading.setTextSize(12);
        loading.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams loadingParams = new LinearLayout.LayoutParams(-1, -2);
        loadingParams.topMargin = 34;
        splash.addView(loading, loadingParams);

        web = new WebView(this);
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        web.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String path = uri.getPath() == null ? "" : uri.getPath();
                boolean allowed = "https".equalsIgnoreCase(uri.getScheme())
                    && HOST.equalsIgnoreCase(uri.getHost())
                    && ("/smart-grocery-store-pro/shopkeeper.html".equals(path));
                if (allowed) return false;
                if ("https".equalsIgnoreCase(uri.getScheme()) || "http".equalsIgnoreCase(uri.getScheme())) {
                    try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); } catch (Exception ignored) {}
                }
                return true;
            }
            @Override public void onPageFinished(WebView view, String url) {
                web.setVisibility(View.VISIBLE);
                splash.setVisibility(View.GONE);
            }
            @Override public void onReceivedError(WebView view, WebResourceRequest request,
                                                   android.webkit.WebResourceError error) {
                if (request.isForMainFrame()) {
                    web.setVisibility(View.VISIBLE);
                    splash.setVisibility(View.GONE);
                }
            }
        });
        web.setVisibility(View.INVISIBLE);
        root.addView(web, new FrameLayout.LayoutParams(-1, -1));
        root.addView(splash, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
        if (state == null || web.restoreState(state) == null) web.loadUrl(ENTRY);
    }

    @Override protected void onSaveInstanceState(Bundle out) {
        if (web != null) web.saveState(out);
        super.onSaveInstanceState(out);
    }

    @Override public void onBackPressed() {
        if (web != null && web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    @Override protected void onDestroy() {
        if (web != null) { web.stopLoading(); web.destroy(); web = null; }
        super.onDestroy();
    }
}
