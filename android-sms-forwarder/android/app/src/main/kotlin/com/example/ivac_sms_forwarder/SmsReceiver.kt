package com.example.ivac_sms_forwarder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "IVAC_SmsReceiver"
        private const val DEFAULT_SERVER_URL = "http://192.168.31.140:3000/ivac-sms"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) return

            val sender = messages[0].displayOriginatingAddress ?: "Unknown"
            val bodyBuilder = StringBuilder()
            for (sms in messages) {
                bodyBuilder.append(sms.displayMessageBody)
            }
            val messageBody = bodyBuilder.toString()

            Log.d(TAG, "SMS Received from: $sender")

            // Check for IVAC or OTP keywords
            val upper = messageBody.uppercase(Locale.ROOT)
            val isMatch = upper.contains("IVAC") || upper.contains("OTP")

            if (!isMatch) {
                Log.d(TAG, "Ignored SMS: No IVAC or OTP keyword found.")
                return
            }

            Log.d(TAG, "Matched IVAC/OTP SMS! Forwarding to server...")

            // Read target URL from Flutter SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val targetUrl = prefs.getString("flutter.server_url", DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL

            val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).format(Date())

            // Forward in background thread
            thread {
                sendPostRequest(targetUrl, sender, messageBody, timestamp)
            }

            // Notify Flutter UI if MainActivity is active
            MainActivity.sendSmsEventToFlutter(sender, messageBody, timestamp)

        } catch (e: Exception) {
            Log.e(TAG, "Error in onReceive: ${e.message}", e)
        }
    }

    private fun sendPostRequest(targetUrl: String, sender: String, message: String, timestamp: String) {
        var connection: HttpURLConnection? = null
        try {
            val url = URL(targetUrl)
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json; utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.connectTimeout = 8000
            connection.readTimeout = 8000
            connection.doOutput = true

            val json = JSONObject().apply {
                put("sender", sender)
                put("message", message)
                put("timestamp", timestamp)
            }

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(json.toString())
                writer.flush()
            }

            val responseCode = connection.responseCode
            Log.d(TAG, "Server responded with HTTP code: $responseCode")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send SMS to $targetUrl: ${e.message}")
        } finally {
            connection?.disconnect()
        }
    }
}
