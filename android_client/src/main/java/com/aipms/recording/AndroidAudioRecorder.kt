package com.aipms.recording

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

class AndroidAudioRecorder(
    private val context: Context
) {
    private var recorder: MediaRecorder? = null
    var currentFile: File? = null
        private set

    fun start(): File {
        stop()
        val outputFile = File(
            context.cacheDir,
            "ai-pms-meeting-${System.currentTimeMillis()}.m4a"
        )
        val nextRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        nextRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        nextRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        nextRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        nextRecorder.setAudioEncodingBitRate(128_000)
        nextRecorder.setAudioSamplingRate(44_100)
        nextRecorder.setOutputFile(outputFile.absolutePath)
        nextRecorder.prepare()
        nextRecorder.start()
        recorder = nextRecorder
        currentFile = outputFile
        return outputFile
    }

    fun stop(): File? {
        val activeRecorder = recorder ?: return currentFile
        runCatching { activeRecorder.stop() }
        activeRecorder.release()
        recorder = null
        return currentFile
    }

    fun discard() {
        stop()
        currentFile?.delete()
        currentFile = null
    }
}
