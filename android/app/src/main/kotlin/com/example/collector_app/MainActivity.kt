package com.balance.collectorApp

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import recieptservice.com.recieptservice.PrinterInterface

class MainActivity : FlutterActivity() {
    private val CHANNEL = "printer_channel"
    private var printerService: PrinterInterface? = null
    private var isServiceBound = false

    // Queue pending calls until service is ready
    private val pendingCalls = mutableListOf<() -> Unit>()

    private val conn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            printerService = PrinterInterface.Stub.asInterface(service)
            isServiceBound = true

            // Flush any calls that came in before service was ready
            pendingCalls.forEach { it.invoke() }
            pendingCalls.clear()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            printerService = null
            isServiceBound = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bindPrinterService()
    }

    private fun bindPrinterService() {
        val intent = Intent().apply {
            setClassName(
                "recieptservice.com.recieptservice",
                "recieptservice.com.recieptservice.service.PrinterService"
            )
        }
        val bound = bindService(intent, conn, Context.BIND_AUTO_CREATE)
        if (!bound) {
            android.util.Log.e("PrinterService", "Failed to bind to printer service. Is the service installed?")
        }
    }

    private fun executeWhenReady(result: MethodChannel.Result, action: () -> Unit) {
        if (isServiceBound && printerService != null) {
            action()
        } else {
            // Queue it — service not ready yet
            pendingCalls.add {
                if (printerService != null) {
                    action()
                } else {
                    result.error("SERVICE_UNAVAILABLE", "Printer service not connected", null)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "printText" -> {
                        val text = call.argument<String>("text")
                        executeWhenReady(result) {
                            printerService?.printText(text)
                            result.success("Printed")
                        }
                    }

                    "printQRCode" -> {
                        val data = call.argument<String>("data")
                        executeWhenReady(result) {
                            printerService?.printQRCode(data, 8, 2)
                            result.success("QR Printed")
                        }
                    }

                    "printBarcode" -> {
                        val data = call.argument<String>("data")
                        executeWhenReady(result) {
                            printerService?.printBarCode(data, 8, 162, 2)
                            result.success("Barcode Printed")
                        }
                    }

                    "isReady" -> {
                        result.success(isServiceBound && printerService != null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isServiceBound) {
            unbindService(conn)
            isServiceBound = false
        }
    }
}