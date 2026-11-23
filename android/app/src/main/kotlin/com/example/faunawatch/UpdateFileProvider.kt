package com.example.faunawatch

import androidx.core.content.FileProvider

/**
 * Lets Android's installer read a downloaded update (see `res/xml/update_paths.xml`).
 *
 * Its own class, because the manifest can hold only one provider per class name and
 * plugins (e.g. the photo picker) declare their own file providers too.
 */
class UpdateFileProvider : FileProvider()
