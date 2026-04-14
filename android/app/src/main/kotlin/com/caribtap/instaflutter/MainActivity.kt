package com.caribtap.instaflutter

import android.content.pm.PackageManager
import com.caribtap.instaflutter.android.BuildConfig
import io.flutter.embedding.android.FlutterFragmentActivity

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin


class MainActivity : FlutterFragmentActivity()
{
    private val envChannel = "caribtap/app_env"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        flutterEngine.plugins.add(GoogleMobileAdsPlugin())
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "adFactoryExample",
            NativeAdFactoryExample(layoutInflater)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, envChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getGoogleMapsApiKey" -> result.success(readGoogleMapsApiKey())
                    "getGooglePlacesApiKey" -> result.success(readGooglePlacesApiKey())
                    "getGeminiApiKey" -> result.success(readGeminiApiKey())
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(
            flutterEngine,
            "adFactoryExample"
        )
    }

    private fun readGoogleMapsApiKey(): String {
        val fromBuildConfig = BuildConfig.GOOGLE_MAPS_API_KEY
        if (fromBuildConfig.isNotBlank()) return fromBuildConfig

        return try {
            val appInfo = applicationContext.packageManager.getApplicationInfo(
                applicationContext.packageName,
                PackageManager.GET_META_DATA
            )
            appInfo.metaData?.getString("com.google.android.geo.API_KEY") ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    private fun readGooglePlacesApiKey(): String {
        return BuildConfig.GOOGLE_PLACES_API_KEY
    }

    private fun readGeminiApiKey(): String {
        return BuildConfig.GEMINI_API_KEY
    }
}
