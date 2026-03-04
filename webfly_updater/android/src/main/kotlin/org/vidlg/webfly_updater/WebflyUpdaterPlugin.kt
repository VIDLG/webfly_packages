package org.vidlg.webfly_updater

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class WebflyUpdaterPlugin : FlutterPlugin, MethodCallHandler {
    private var applicationContext: Context? = null
    private var methodChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledSignature" -> {
                try {
                    val context = applicationContext!!
                    val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        context.packageManager.getPackageInfo(
                            context.packageName,
                            PackageManager.GET_SIGNING_CERTIFICATES
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        context.packageManager.getPackageInfo(
                            context.packageName,
                            PackageManager.GET_SIGNATURES
                        )
                    }
                    result.success(extractSignatures(packageInfo))
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }
            "getApkSignature" -> {
                val apkPath = call.argument<String>("path")
                if (apkPath == null) {
                    result.error("ERROR", "path is required", null)
                    return
                }
                try {
                    val context = applicationContext!!
                    val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        context.packageManager.getPackageArchiveInfo(
                            apkPath,
                            PackageManager.GET_SIGNING_CERTIFICATES
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        context.packageManager.getPackageArchiveInfo(
                            apkPath,
                            PackageManager.GET_SIGNATURES
                        )
                    }
                    result.success(extractSignatures(packageInfo))
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun extractSignatures(packageInfo: PackageInfo?): String {
        if (packageInfo == null) return "unknown"
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            packageInfo.signatures
        }
        if (signatures.isNullOrEmpty()) return "unknown"
        return signatures.map { it.toHex() }.joinToString(",")
    }

    private fun Signature.toHex(): String {
        val md = java.security.MessageDigest.getInstance("SHA-256")
        val digest = md.digest(toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    companion object {
        private const val CHANNEL_NAME = "webfly_updater/signature"
    }
}
