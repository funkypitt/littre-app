package ch.littre.littre_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Home-screen widget: the word of the day, its nature and the start of its definition. */
class WordOfDayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val word = runCatching { WordOfDay.today(context) }.getOrNull()
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_word_of_day)
            views.setTextViewText(R.id.wotd_word, word?.word ?: "Le Littré")
            views.setTextViewText(R.id.wotd_nature, word?.nature ?: "")
            views.setTextViewText(R.id.wotd_preview, word?.preview ?: "mot du jour")
            views.setOnClickPendingIntent(R.id.wotd_root, open)
            manager.updateAppWidget(id, views)
        }
    }
}
