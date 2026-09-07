package ch.littre.littre_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.time.LocalDate
import java.util.Random

/** Today's entry, shared by the app (Flutter), the home-screen widget and the content provider. */
data class WordOfDay(val id: Int, val word: String, val nature: String?, val html: String, val etymology: String?) {
    val text: String get() = plain(html) + (etymology?.let { "\n\n" + plain(it) } ?: "")
    val preview: String get() = plain(html).let { if (it.length <= 120) it else it.substring(0, 120) + "…" }

    companion object {
        private const val PREFS = "FlutterSharedPreferences"   // shared_preferences' file on Android
        private const val KEY_DATE = "flutter.wotd_date"
        private const val KEY_ID = "flutter.wotd_id"

        fun plain(html: String): String = html
            .replace(Regex("<br\\s*/?>", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("</(p|div|li)>", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("<[^>]*>"), "")
            .replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&nbsp;", " ")
            .replace(Regex("[ \\t]+"), " ").replace(Regex("\\n\\s*\\n+"), "\n\n").trim()

        /**
         * The Flutter side picks a random entry once a day and remembers (date, id) in its
         * preferences. Here the same preferences are read; if today has no entry yet (the app
         * was not opened), one is drawn from the day number and written back, so the app then
         * shows the same word.
         */
        fun today(context: Context): WordOfDay? {
            val db = openDatabase(context) ?: return null
            try {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val today = LocalDate.now().toString()
                var id: Int? = if (prefs.getString(KEY_DATE, null) == today) {
                    // shared_preferences stores ints as Long on Android
                    runCatching { prefs.getLong(KEY_ID, -1L).toInt() }.getOrNull()?.takeIf { it > 0 }
                        ?: runCatching { prefs.getInt(KEY_ID, -1) }.getOrNull()?.takeIf { it > 0 }
                } else null
                if (id == null) {
                    val count = db.rawQuery("SELECT COUNT(*) FROM entries", null).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }
                    if (count == 0) return null
                    val n = Random(LocalDate.now().toEpochDay()).nextInt(count)
                    id = db.rawQuery("SELECT id FROM entries ORDER BY id LIMIT 1 OFFSET ?", arrayOf(n.toString())).use { c -> if (c.moveToFirst()) c.getInt(0) else return null }
                    prefs.edit().putString(KEY_DATE, today).putLong(KEY_ID, id.toLong()).apply()
                }
                return db.rawQuery("SELECT id, terme, nature, corps, etymologie FROM entries WHERE id = ?", arrayOf(id.toString())).use { c ->
                    if (!c.moveToFirst()) null
                    else WordOfDay(c.getInt(0), c.getString(1), c.getString(2)?.let { plain(it) }?.ifBlank { null }, c.getString(3), c.getString(4))
                }
            } finally { db.close() }
        }

        /** sqflite's database file; copied from the Flutter assets if the app never ran. */
        private fun openDatabase(context: Context): SQLiteDatabase? {
            val file = context.getDatabasePath("littre.db")
            if (!file.exists() || file.length() == 0L) {
                runCatching {
                    file.parentFile?.mkdirs()
                    val tmp = File(file.parentFile, "littre.db.tmp")
                    context.assets.open("flutter_assets/assets/littre.db").use { i -> tmp.outputStream().use { i.copyTo(it) } }
                    if (!tmp.renameTo(file)) tmp.copyTo(file, overwrite = true)
                }.onFailure { return null }
            }
            return runCatching { SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY) }.getOrNull()
        }
    }
}
