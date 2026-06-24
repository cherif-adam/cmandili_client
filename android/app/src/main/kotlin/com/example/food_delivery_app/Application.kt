package com.cmandili.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.app.FlutterApplication

class Application : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

            // Standard order status updates (confirmed, preparing, on the way…)
            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders",
                    "Order Updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Notifications about your orders"
                    enableVibration(true)
                    setShowBadge(true)
                }
            )

            // Urgent alerts (driver on the way, picked up)
            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders_urgent",
                    "Urgent Order Updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Urgent alerts for your active order"
                    enableVibration(true)
                    setShowBadge(true)
                }
            )
        }
    }
}
