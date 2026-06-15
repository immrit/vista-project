package ir.coffevista.vista

import android.app.Activity
import android.app.Application
import android.os.Bundle
import io.adtrace.sdk.AdTrace
import io.adtrace.sdk.AdTraceConfig
import io.adtrace.sdk.LogLevel

class GlobalApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // App Token from Wizard Step 2
        val appToken = "8cbj8mn5pb2s"
        val environment = AdTraceConfig.ENVIRONMENT_PRODUCTION
        val config = AdTraceConfig(this, appToken, environment)
        
        // Logging enabled per Wizard configuration
        config.setLogLevel(LogLevel.VERBOSE)
        
        AdTrace.onCreate(config)

        // Setup lifecycle callbacks to track sessions automatically
        registerActivityLifecycleCallbacks(AdTraceLifecycleCallbacks())
    }

    private class AdTraceLifecycleCallbacks : ActivityLifecycleCallbacks {
        override fun onActivityResumed(activity: Activity) {
            AdTrace.onResume()
        }
        override fun onActivityPaused(activity: Activity) {
            AdTrace.onPause()
        }
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
        override fun onActivityStarted(activity: Activity) {}
        override fun onActivityStopped(activity: Activity) {}
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
        override fun onActivityDestroyed(activity: Activity) {}
    }
}
