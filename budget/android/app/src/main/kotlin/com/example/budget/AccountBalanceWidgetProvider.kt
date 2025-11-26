package com.budget.tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Android widget provider for displaying account balance.
 * 
 * This widget displays the balance for a user-selected account in Cashew.
 * It reads widget data stored by the Flutter app via the home_widget package
 * and updates the widget UI accordingly.
 * 
 * The widget supports:
 * - Displaying account name, balance, and currency
 * - Customizable background color and transparency
 * - Tap action to open the Cashew app to view account details
 * - Periodic updates (every 24 hours) and manual updates from the app
 */
class AccountBalanceWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->

            val views = RemoteViews(context.packageName, R.layout.account_balance_widget_layout).apply {
                // Set account name text
                try {
                  setTextViewText(R.id.account_name, widgetData.getString("accountBalanceAccountName", null)
                  ?: "Account")
                }catch (e: Exception){}

                // Set account balance amount
                try {
                  setTextViewText(R.id.account_balance, widgetData.getString("accountBalanceAmount", null)
                  ?: "0.00")
                }catch (e: Exception){}

                // Set currency/info text
                try {
                  setTextViewText(R.id.account_currency, widgetData.getString("accountBalanceCurrency", null)
                  ?: "Tap to view account")
                }catch (e: Exception){}

                // Apply background color from widget settings
                try {
                  setInt(R.id.widget_background, "setColorFilter",  android.graphics.Color.parseColor(widgetData.getString("widgetColorBackground", null)
                  ?: "#FFFFFF"));
                }catch (e: Exception){}

                // Apply background transparency/alpha
                try {
                  val alpha = Integer.parseInt(widgetData.getString("widgetAlpha", null)?: "255")
                  setInt(R.id.widget_background, "setImageAlpha",  alpha);
                }catch (e: Exception){}

                // Apply text colors
                try {
                  setInt(R.id.account_name, "setTextColor",  android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                  ?: "#FFFFFF"))
                  setInt(R.id.account_balance, "setTextColor",  android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                  ?: "#FFFFFF"))
                  setInt(R.id.account_currency, "setTextColor",  android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                  ?: "#FFFFFF"))
                }catch (e: Exception){}

                // Set click action to open the app and view account details
                try {
                  val pendingIntentWithData = HomeWidgetLaunchIntent.getActivity(
                          context,
                          MainActivity::class.java,
                          Uri.parse("accountBalanceLaunchWidget"))
                  setOnClickPendingIntent(R.id.widget_container, pendingIntentWithData)
                }catch (e: Exception){}

            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
