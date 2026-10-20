package com.example.ivac_sms_forwarder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.ivac_sms_forwarder/sms"
        private var methodChannel: MethodChannel? = null

        fun sendSmsEventToFlutter(sender: String, message: String, timestamp: String) {
            methodChannel?.invokeMethod("onSmsReceived", mapOf(
                "sender" to sender,
                "message" to message,
                "timestamp" to timestamp
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        methodChannel = null
    }
}
