package com.quazar.quazar_passport

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Bundle
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        bindProcessToWifi()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> {
                        val method = call.argument<String>("method") ?: "GET"
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("ARG", "url required", null)
                            return@setMethodCallHandler
                        }
                        val timeoutMs = call.argument<Int>("timeoutMs") ?: 12_000
                        @Suppress("UNCHECKED_CAST")
                        val headers =
                            call.argument<Map<String, String>>("headers")
                                ?: emptyMap()
                        val body = call.argument<String>("body")
                        val bodyBase64 = call.argument<String>("bodyBase64")
                        Thread {
                            try {
                                result.success(
                                    httpRequest(
                                        method,
                                        url,
                                        timeoutMs,
                                        headers,
                                        body,
                                        bodyBase64,
                                    ),
                                )
                            } catch (e: Exception) {
                                Log.e(TAG, "$method $url failed: ${e.message}")
                                result.error("HTTP", e.message, null)
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** LAN-узлы доступны только через Wi‑Fi; иначе Android может слать HTTP в LTE. */
    private fun bindProcessToWifi() {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val wifiNetwork =
            cm.allNetworks.firstOrNull { network ->
                val caps = cm.getNetworkCapabilities(network) ?: return@firstOrNull false
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                    caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            }
        if (wifiNetwork == null) {
            Log.w(TAG, "No WiFi network to bind")
            return
        }
        val ok = cm.bindProcessToNetwork(wifiNetwork)
        Log.i(TAG, "bindProcessToNetwork(wifi)=$ok")
    }

    private fun httpRequest(
        method: String,
        url: String,
        timeoutMs: Int,
        headers: Map<String, String>,
        body: String?,
        bodyBase64: String?,
    ): Map<String, Any> {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = timeoutMs
        conn.readTimeout = timeoutMs
        conn.requestMethod = method.uppercase()
        headers.forEach { (k, v) -> conn.setRequestProperty(k, v) }
        val requestBodyBytes =
            when {
                !bodyBase64.isNullOrEmpty() ->
                    Base64.decode(bodyBase64, Base64.NO_WRAP)
                body != null -> body.toByteArray(Charsets.UTF_8)
                else -> null
            }
        if (requestBodyBytes != null &&
            method.uppercase() in listOf("POST", "PUT", "PATCH")
        ) {
            conn.doOutput = true
            conn.setFixedLengthStreamingMode(requestBodyBytes.size)
            conn.outputStream.use { it.write(requestBodyBytes) }
        }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val bodyBytes = stream?.use { it.readBytes() } ?: ByteArray(0)
        conn.disconnect()
        // Base64: MethodChannel ломает кириллицу в JSON-строках; список int — на больших ответах.
        return mapOf(
            "statusCode" to code,
            "bodyBase64" to Base64.encodeToString(bodyBytes, Base64.NO_WRAP),
        )
    }

    companion object {
        private const val TAG = "QuazarPassport"
        private const val CHANNEL = "com.quazar.quazar_passport/lan_http"
    }
}
