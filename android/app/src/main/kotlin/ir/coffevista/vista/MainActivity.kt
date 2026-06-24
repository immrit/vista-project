
package ir.coffevista.vista

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Parcelable
import android.view.View
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.cafebazaar.poolakey.Payment
import ir.cafebazaar.poolakey.config.PaymentConfiguration
import ir.cafebazaar.poolakey.config.SecurityCheck
import ir.cafebazaar.poolakey.request.PurchaseRequest
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity: AudioServiceFragmentActivity() {

    // Request highest available refresh rate (120Hz on supported displays).
    // flutter_displaymode is unavailable; we call WindowManager directly.
    // Sets both preferredDisplayModeId (exact mode) and preferredRefreshRate (hint)
    // so MIUI/HyperOS "Smart Refresh Rate" honours at least one of the two APIs.
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val params = window.attributes
            @Suppress("DEPRECATION")
            val modes = windowManager.defaultDisplay.supportedModes
            if (modes.size > 1) {
                val highest = modes.maxByOrNull { it.refreshRate }
                if (highest != null) {
                    params.preferredDisplayModeId = highest.modeId
                }
            }
            // Fallback rate hint: MIUI may honour this even if mode enumeration
            // returns only one mode for non-whitelisted apps.
            params.preferredRefreshRate = 120f
            window.attributes = params
        }
    }

    private val CHANNEL = "ir.coffevista.vista/bazaar_native"
    private val SYSTEM_UI_CHANNEL = "ir.coffevista.vista/system_ui"
    private val SHARE_CHANNEL = "ir.coffevista.vista/share_receiver"
    private lateinit var payment: Payment

    // نگه داشتن داده‌های share تا زمانی که Flutter آماده باشد
    private var pendingShareData: Map<String, Any?>? = null
    private var shareChannel: MethodChannel? = null
    
    // کلید RSA
    private val RSA_KEY = "MIHNMA0GCSqGSIb3DQEBAQUAA4G7ADCBtwKBrwDFm5WUUaqhq2Ha3Al1b8OmGNnBCsPNNjbp04bDJUCFo/QTF6P9JPpqAwVeo0MqR84WEo3KKZBwIYA+aJZuVPYjZ5J6S9tJ1McWKY0v4+6s4PR07Z5N55TMCFz0ofi0GsnpQHVp94zLvhYBQqQatLBq0XsmOiPWTHt2UgP7d0ib2anR2LtRE/1J1WPe2/lji4u8b1+CLRgfT3hzdfqv2RkrpAn69GYqEfUuohQyQK8CAwEAAQ=="

    // وقتی اپ از intent share شروع شود
    override fun onStart() {
        super.onStart()
        handleShareIntent(intent)
    }

    // وقتی اپ در حال اجراست و intent جدید می‌رسد
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val securityCheck = SecurityCheck.Enable(rsaPublicKey = RSA_KEY)
        val paymentConfig = PaymentConfiguration(localSecurityCheck = securityCheck)
        payment = Payment(context = this, config = paymentConfig)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> connectToBazaar(result)
                
                // متد خرید معمولی (سکه، الماس)
                "purchase" -> handlePurchase(call.argument("productId"), call.argument("payload"), result, isSubscription = false)
                
                // 🔴 متد مخصوص اشتراک (تیک طلایی)
                "subscribe" -> handlePurchase(call.argument("productId"), call.argument("payload"), result, isSubscription = true)
                
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_UI_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSystemBars" -> {
                    setSystemBars(
                        call.argument<Number>("statusBarColor")?.toLong()?.toInt(),
                        call.argument<Number>("navigationBarColor")?.toLong()?.toInt(),
                        call.argument<Boolean>("lightStatusBarIcons") ?: false,
                        call.argument<Boolean>("lightNavigationBarIcons") ?: false
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ir.coffevista.updater").setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    installApk(filePath)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "filePath is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // ══════════════════════════════════════════════════════════
        //  Share Receiver Channel
        // ══════════════════════════════════════════════════════════
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter calls this to check if there's pending share data
                "getInitialShare" -> {
                    result.success(pendingShareData)
                    pendingShareData = null
                }
                else -> result.notImplemented()
            }
        }

        // اگر قبل از آماده‌شدن Flutter داده share بود، الان بفرست
        pendingShareData?.let {
            shareChannel!!.invokeMethod("onShare", it)
            pendingShareData = null
        }
    }

    @Suppress("DEPRECATION")
    private fun setSystemBars(
        statusBarColor: Int?,
        navigationBarColor: Int?,
        lightStatusBarIcons: Boolean,
        lightNavigationBarIcons: Boolean
    ) {
        if (statusBarColor != null) {
            window.statusBarColor = statusBarColor
        }
        if (navigationBarColor != null) {
            window.navigationBarColor = navigationBarColor
        }

        var flags = window.decorView.systemUiVisibility
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = if (lightStatusBarIcons) {
                flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            } else {
                flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            flags = if (lightNavigationBarIcons) {
                flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            } else {
                flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
            }
        }
        window.decorView.systemUiVisibility = flags

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }

    private fun connectToBazaar(result: MethodChannel.Result) {
        payment.connect {
            connectionSucceed { try { result.success(true) } catch (e: Exception) {} }
            connectionFailed { try { result.error("FAIL", it.message, null) } catch (e: Exception) {} }
            disconnected { }
        }
    }

    private fun handlePurchase(productId: String?, payload: String?, result: MethodChannel.Result, isSubscription: Boolean) {
        if (productId == null) {
            result.error("ARGS", "ProductId required", null)
            return
        }
        
        val request = PurchaseRequest(productId, payload ?: "")
        
        val onSuccess: (ir.cafebazaar.poolakey.entity.PurchaseInfo) -> Unit = { info ->
            // برگرداندن اطلاعات کامل به فلاتر
            result.success(mapOf(
                "purchaseToken" to info.purchaseToken,
                "packageName" to info.packageName,
                "orderId" to info.orderId
            ))
        }

        val onFailure: (Throwable) -> Unit = { 
            result.error("FAILED", it.message, null) 
        }

        val onCancel: () -> Unit = { 
            result.error("CANCELED", "User canceled", null) 
        }

        if (isSubscription) {
            // استفاده از متد مخصوص اشتراک
            payment.subscribeProduct(registry = activityResultRegistry, request = request) {
                purchaseSucceed(onSuccess)
                purchaseCanceled(onCancel)
                purchaseFailed(onFailure)
            }
        } else {
            // استفاده از متد خرید معمولی
            payment.purchaseProduct(registry = activityResultRegistry, request = request) {
                purchaseSucceed(onSuccess)
                purchaseCanceled(onCancel)
                purchaseFailed(onFailure)
            }
        }
    }

    private fun installApk(filePath: String) {
        try {
            val file = File(filePath)
            if (!file.exists()) return

            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(
                FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file),
                "application/vnd.android.package-archive"
            )
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // ══════════════════════════════════════════════════════════
    //  Share Intent Processing
    // ══════════════════════════════════════════════════════════

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        val type = intent.type ?: return

        val data: Map<String, Any?> = when (action) {
            Intent.ACTION_SEND -> processSingleShare(intent, type)
            Intent.ACTION_SEND_MULTIPLE -> processMultipleShare(intent, type)
            else -> return
        } ?: return

        // اگر Flutter engine آماده است، مستقیم بفرست
        if (shareChannel != null) {
            shareChannel!!.invokeMethod("onShare", data)
        } else {
            // Flutter هنوز آماده نیست، نگه‌دار
            pendingShareData = data
        }
    }

    private fun processSingleShare(intent: Intent, mimeType: String): Map<String, Any?>? {
        return try {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }

            val filePaths = mutableListOf<String>()
            uri?.let { resolvedUri ->
                copyUriToCache(resolvedUri, mimeType)?.let { filePaths.add(it) }
            }

            mapOf(
                "type" to mimeType,
                "text" to text,
                "filePaths" to filePaths,
                "isMultiple" to false
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun processMultipleShare(intent: Intent, mimeType: String): Map<String, Any?>? {
        return try {
            val uris: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }

            val filePaths = uris
                ?.take(10) // حداکثر ۱۰ فایل
                ?.mapNotNull { uri -> copyUriToCache(uri, mimeType) }
                ?: emptyList()

            mapOf(
                "type" to mimeType,
                "text" to null,
                "filePaths" to filePaths,
                "isMultiple" to true
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * کپی کردن content URI به cache dir اپ.
     * content:// URI ها فقط در طول intent معتبرند — باید کپی شوند.
     */
    private fun copyUriToCache(uri: Uri, mimeType: String): String? {
        return try {
            val ext = mimeTypeToExtension(mimeType)
            val cacheDir = File(cacheDir, "shared_media").also { it.mkdirs() }
            val destFile = File(cacheDir, "share_${System.currentTimeMillis()}$ext")

            contentResolver.openInputStream(uri)?.use { input: InputStream ->
                FileOutputStream(destFile).use { output -> input.copyTo(output) }
            }

            if (destFile.exists() && destFile.length() > 0) destFile.absolutePath else null
        } catch (e: Exception) {
            null
        }
    }

    private fun mimeTypeToExtension(mimeType: String): String {
        return when {
            mimeType.startsWith("image/jpeg") || mimeType.startsWith("image/jpg") -> ".jpg"
            mimeType.startsWith("image/png") -> ".png"
            mimeType.startsWith("image/gif") -> ".gif"
            mimeType.startsWith("image/webp") -> ".webp"
            mimeType.startsWith("image/") -> ".jpg"
            mimeType.startsWith("video/mp4") -> ".mp4"
            mimeType.startsWith("video/") -> ".mp4"
            mimeType.startsWith("text/") -> ".txt"
            else -> ""
        }
    }
}
