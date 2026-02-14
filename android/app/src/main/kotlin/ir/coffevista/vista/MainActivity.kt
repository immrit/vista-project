
package ir.coffevista.vista

import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.cafebazaar.poolakey.Payment
import ir.cafebazaar.poolakey.config.PaymentConfiguration
import ir.cafebazaar.poolakey.config.SecurityCheck
import ir.cafebazaar.poolakey.request.PurchaseRequest

class MainActivity: AudioServiceFragmentActivity() {
    private val CHANNEL = "ir.coffevista.vista/bazaar_native"
    private lateinit var payment: Payment
    
    // کلید RSA
    private val RSA_KEY = "MIHNMA0GCSqGSIb3DQEBAQUAA4G7ADCBtwKBrwDFm5WUUaqhq2Ha3Al1b8OmGNnBCsPNNjbp04bDJUCFo/QTF6P9JPpqAwVeo0MqR84WEo3KKZBwIYA+aJZuVPYjZ5J6S9tJ1McWKY0v4+6s4PR07Z5N55TMCFz0ofi0GsnpQHVp94zLvhYBQqQatLBq0XsmOiPWTHt2UgP7d0ib2anR2LtRE/1J1WPe2/lji4u8b1+CLRgfT3hzdfqv2RkrpAn69GYqEfUuohQyQK8CAwEAAQ=="

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
}
