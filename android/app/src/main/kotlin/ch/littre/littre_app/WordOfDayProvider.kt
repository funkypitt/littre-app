package ch.littre.littre_app

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

/**
 * content://ch.littre.littre_app.wotd/today → one row: id, word, nature, preview, text, html.
 * Read-only, public: the Littré is public domain, and Reader's Launcher reads this for its
 * "mot du jour" tile.
 */
class WordOfDayProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(uri: Uri, projection: Array<String>?, selection: String?, selectionArgs: Array<String>?, sortOrder: String?): Cursor {
        val cursor = MatrixCursor(arrayOf("_id", "word", "nature", "preview", "text", "html"))
        val ctx = context ?: return cursor
        WordOfDay.today(ctx)?.let { w -> cursor.addRow(arrayOf(w.id, w.word, w.nature, w.preview, w.text, w.html)) }
        return cursor
    }

    override fun getType(uri: Uri) = "vnd.android.cursor.item/vnd.littre.wotd"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?) = 0
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?) = 0

    companion object { const val AUTHORITY = "ch.littre.littre_app.wotd" }
}
