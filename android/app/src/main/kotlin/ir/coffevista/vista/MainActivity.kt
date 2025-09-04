package ir.coffevista.vista

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.vista.app/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareToInstagram" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val packageName = call.argument<String>("packageName")

                    if (imagePath != null && packageName != null) {
                        shareToInstagram(imagePath, packageName)
                        result.success("Instagram opened successfully")
                    } else {
                        result.error("INVALID_ARGUMENTS", "Image path or package name is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun shareToInstagram(imagePath: String, packageName: String) {
        try {
            android.util.Log.d("InstagramShare", "Starting Instagram share with package: $packageName")
            android.util.Log.d("InstagramShare", "Image path: $imagePath")

            // First check if Instagram is installed
            val isInstagramInstalled = isPackageInstalled(packageName)
            android.util.Log.d("InstagramShare", "Is Instagram installed: $isInstagramInstalled")

            if (!isInstagramInstalled) {
                android.util.Log.d("InstagramShare", "Instagram not installed, opening Play Store")
                // Instagram is not installed, open Play Store
                val playStoreIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
                }
                startActivity(playStoreIntent)
                return
            }

            val file = java.io.File(imagePath)
            val imageUri = androidx.core.content.FileProvider.getUriForFile(
                this,
                "ir.coffevista.vista.fileprovider",
                file
            )
            android.util.Log.d("InstagramShare", "Generated URI: $imageUri")

            // Try multiple Instagram sharing methods
            var success = false

            // Method 1: Instagram Stories Intent (preferred)
            if (!success) {
                android.util.Log.d("InstagramShare", "Trying Instagram Stories Intent...")
                success = tryShareToInstagramStories(imageUri, packageName)
                android.util.Log.d("InstagramShare", "Instagram Stories Intent success: $success")
            }

            // Method 2: General Instagram Intent
            if (!success) {
                android.util.Log.d("InstagramShare", "Trying General Instagram Intent...")
                success = tryShareToInstagramGeneral(imageUri, packageName)
                android.util.Log.d("InstagramShare", "General Instagram Intent success: $success")
            }

            // Method 3: Generic share with Instagram as target
            if (!success) {
                android.util.Log.d("InstagramShare", "Trying Generic Share Intent...")
                success = tryShareGenericWithInstagram(imageUri)
                android.util.Log.d("InstagramShare", "Generic Share Intent success: $success")
            }

            // Method 4: Try opening Instagram directly with the image
            if (!success) {
                android.util.Log.d("InstagramShare", "Trying to open Instagram directly...")
                success = tryOpenInstagramWithImage(imageUri, packageName)
                android.util.Log.d("InstagramShare", "Direct Instagram open success: $success")
            }

            // Method 5: Try without specifying package (let Android choose)
            if (!success) {
                android.util.Log.d("InstagramShare", "Trying generic intent without package...")
                success = tryGenericIntentWithoutPackage(imageUri)
                android.util.Log.d("InstagramShare", "Generic intent success: $success")
            }

            // If all methods failed, try to open Instagram app directly
            if (!success) {
                android.util.Log.d("InstagramShare", "All methods failed, opening Instagram app...")
                tryOpenInstagramApp(packageName)
            }

        } catch (e: Exception) {
            e.printStackTrace()
            android.util.Log.e("InstagramShare", "Error in shareToInstagram: ${e.message}")

            // Last resort: try alternative package names
            val alternativePackages = arrayOf("com.instagram.android", "com.instagram.igtv")
            for (altPackage in alternativePackages) {
                if (altPackage != packageName && isPackageInstalled(altPackage)) {
                    android.util.Log.d("InstagramShare", "Trying alternative package: $altPackage")
                    tryOpenInstagramApp(altPackage)
                    return
                }
            }

            // If no alternatives work, try the original
            tryOpenInstagramApp(packageName)
        }
    }

    private fun tryShareToInstagramStories(imageUri: Uri, packageName: String): Boolean {
        return try {
            val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                setDataAndType(imageUri, "image/*")
                // فقط تصویر اصلی را ارسال می‌کنیم (بدون background_asset_uri)
                putExtra("source_application", "ir.coffevista.vista")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }

            // Check if the intent can be resolved
            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun tryShareToInstagramStoriesWithSticker(backgroundUri: Uri, postCardUri: Uri, packageName: String): Boolean {
        return try {
            // رویکرد جدید: ارسال بک‌گراند به عنوان تصویر اصلی
            val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                // ارسال بک‌گراند به عنوان تصویر اصلی
                setDataAndType(backgroundUri, "image/*")
                // کارت پست به عنوان استیکر تعاملی
                putExtra("interactive_asset_uri", postCardUri)
                putExtra("source_application", "ir.coffevista.vista")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }

            // Check if the intent can be resolved
            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun tryShareToInstagramGeneralWithMultipleImages(backgroundUri: Uri, postCardUri: Uri, packageName: String): Boolean {
        return try {
            // رویکرد جایگزین: ارسال هر دو تصویر با ACTION_SEND_MULTIPLE
            val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                type = "image/*"
                val uris = java.util.ArrayList<Uri>()
                uris.add(backgroundUri)
                uris.add(postCardUri)
                putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                putExtra("source_application", "ir.coffevista.vista")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }

            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun tryShareToInstagramStoriesBackgroundOnly(imageUri: Uri, packageName: String): Boolean {
        return try {
            val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                // فقط به عنوان بک‌گراند ارسال می‌کنیم (بدون setDataAndType)
                putExtra("background_asset_uri", imageUri)
                putExtra("source_application", "ir.coffevista.vista")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }

            // Check if the intent can be resolved
            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun tryShareToInstagramStoriesBackgroundAlternative(imageUri: Uri, packageName: String): Boolean {
        return try {
            val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                // روش جایگزین: فقط بک‌گراند با تنظیمات مختلف
                putExtra("background_asset_uri", imageUri)
                putExtra("source_application", "ir.coffevista.vista")
                putExtra("sticker_asset_uri", "") // خالی برای جلوگیری از تکرار
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }

            // Check if the intent can be resolved
            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun tryShareToInstagramGeneral(imageUri: Uri, packageName: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/*"
                putExtra(Intent.EXTRA_STREAM, imageUri)
                putExtra("source_application", "ir.coffevista.vista")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }

            // Check if the intent can be resolved
            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun tryShareGenericWithInstagram(imageUri: Uri): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/*"
                putExtra(Intent.EXTRA_STREAM, imageUri)
                putExtra("source_application", "ir.coffevista.vista")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            // Create chooser with Instagram as preferred target
            val chooser = Intent.createChooser(intent, "Share to Instagram")
            val activities = packageManager.queryIntentActivities(chooser, 0)
            if (activities.isNotEmpty()) {
                startActivity(chooser)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun tryGenericIntentWithoutPackage(imageUri: Uri): Boolean {
        return try {
            // Try a generic send intent without specifying package
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/*"
                putExtra(Intent.EXTRA_STREAM, imageUri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun tryOpenInstagramWithImage(imageUri: Uri, packageName: String): Boolean {
        return try {
            // Try to open Instagram with the image using a different approach
            val intent = Intent().apply {
                action = Intent.ACTION_VIEW
                data = imageUri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }
            
            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }


    private fun tryOpenInstagramApp(packageName: String) {
        try {
            // Try to open Instagram app directly
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } else {
                // If can't open app, then open Play Store
                val playStoreIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
                }
                startActivity(playStoreIntent)
            }
        } catch (e: Exception) {
            // Last resort: try to open Play Store but only if we don't know the status
            val playStoreIntent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
            }
            startActivity(playStoreIntent)
        }
    }
}
