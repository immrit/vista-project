
package ir.coffevista.vista

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.cafebazaar.poolakey.Payment
import ir.cafebazaar.poolakey.config.PaymentConfiguration
import ir.cafebazaar.poolakey.config.SecurityCheck
import ir.cafebazaar.poolakey.request.PurchaseRequest

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "ir.coffevista.vista/bazaar_native"
    private lateinit var payment: Payment
    
    // کلید RSA
    private val RSA_KEY = "MIHNMA0GCSqGSIb3DQEBAQUAA4G7ADCBtwKBrwDFm5WUUaqhq2Ha3Al1b8OmGNnBCsPNNjbp04bDJUCFo/QTF6P9JPpqAwVeo0MqR84WEo3KKZBwIYA+aJZuVPYjZ5J6S9tJ1McWKY0v4+6s4PR07Z5N55TMCFz0ofi0GsnpQHVp94zLvhYBQqQatLBq0XsmOiPWTHt2UgP7d0ib2anR2LtRE/1J1WPe2/lji4u8b1+CLRgfT3hzdfqv2RkrpAn69GYqEfUuohQyQK8CAwEAAQ=="

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. تنظیمات امنیتی
        val securityCheck = SecurityCheck.Enable(rsaPublicKey = RSA_KEY)
        val paymentConfig = PaymentConfiguration(localSecurityCheck = securityCheck)
        
        // ساخت نمونه پیمنت (از this استفاده می‌کنیم چون FragmentActivity یک Context کامل است)
        payment = Payment(context = this, config = paymentConfig)

        // 2. تنظیم متد چنل
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> connectToBazaar(result)
                "purchase" -> {
                    val productId = call.argument<String>("productId")
                    val payload = call.argument<String>("payload") ?: ""
                    if (productId != null) {
                        purchaseProduct(productId, payload, result)
                    } else {
                        result.error("ARGS", "ProductId is required", null)
                    }
                }
                // متد disconnect در نسخه جدید حذف شده و نیازی به فراخوانی دستی نیست
                else -> result.notImplemented()
            }
        }
    }

    private fun connectToBazaar(result: MethodChannel.Result) {
        payment.connect {
            connectionSucceed {
                // اتصال موفق
                try { result.success(true) } catch (e: Exception) {}
            }
            connectionFailed { throwable ->
                // شکست در اتصال
                try { 
                    result.error("CONNECTION_FAILED", throwable.message, null) 
                } catch (e: Exception) {}
            }
            disconnected {
                // قطع اتصال
            }
        }
    }

    private fun purchaseProduct(productId: String, payload: String, result: MethodChannel.Result) {
        val purchaseRequest = PurchaseRequest(
            productId = productId,
            payload = payload
        )

        // 🔴 استفاده از activityResultRegistry که حالا در دسترس است
        payment.purchaseProduct(
            registry = activityResultRegistry, 
            request = purchaseRequest
        ) {
            purchaseSucceed { purchaseInfo ->
                // خرید موفق
                val response = mapOf(
                    "orderId" to purchaseInfo.orderId,
                    "purchaseToken" to purchaseInfo.purchaseToken,
                    "payload" to purchaseInfo.payload,
                    "packageName" to purchaseInfo.packageName,
                    "purchaseState" to purchaseInfo.purchaseState.toString(),
                    "purchaseTime" to purchaseInfo.purchaseTime
                )
                result.success(response)
            }

            purchaseCanceled {
                // لغو توسط کاربر
                result.error("CANCELED", "User canceled purchase", null)
            }

            purchaseFailed { throwable ->
                // خطای خرید
                result.error("FAILED", throwable.message, null)
            }
        }
    }
}
