package com.example.mobile_car_spa_new

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "mobile.car.mobile_car_spa/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchWhatsApp" -> {
                    val args = call.arguments as? Map<*, *>
                    val phone = (args?.get("phone") as? String)?.trim().orEmpty()
                    val message = (args?.get("message") as? String)?.trim().orEmpty()
                    val ok = launchWhatsApp(phone, message)
                    result.success(ok)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchWhatsApp(rawPhone: String, message: String): Boolean {
        // Normalize phone: keep digits and '+'
        var phone = rawPhone.replace(Regex("[^0-9+]"), "")
        if (phone.isEmpty()) return false
        // If no country code and 10 digits, default to +91 (adjust if needed)
        if (!phone.startsWith("+") && phone.length == 10) {
            phone = "+91$phone"
        }

        return try {
            // Use the official wa.me scheme; WhatsApp will intercept
            val encodedText = Uri.encode(message)
            val uri = Uri.parse("https://wa.me/${phone.replace("+", "")}?text=$encodedText")
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                // Prefer WhatsApp if installed
                setPackage("com.whatsapp")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            // Fallback: open default browser/app for wa.me link
            return try {
                val encodedText = Uri.encode(message)
                val uri = Uri.parse("https://wa.me/${phone.replace("+", "")}?text=$encodedText")
                val fallbackIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
                true
            } catch (e2: Exception) {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
