package com.aipms.recording

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File

/**
 * 10분(기본값) 단위로 자동 분할 녹음하는 레코더.
 *
 * - [setMaxDuration] + [MediaRecorder.OnInfoListener] 조합으로 세그먼트 자동 전환.
 * - 각 세그먼트 완료 시 [onSegmentReady] 콜백 호출(파일이 비어 있으면 스킵).
 * - [stop] 호출 시 현재 세그먼트 파일 반환 — [onSegmentReady]는 호출되지 않음.
 *   마지막 파일 업로드는 호출측에서 직접 수행.
 */
class SegmentedRecorder(
    private val context: Context,
    private val segmentDurationMs: Int = 10 * 60 * 1000   // 10분
) {
    /**
     * 세그먼트가 완료될 때마다 호출됨.
     * 파라미터: (segmentIndex: Int, file: File)
     * 이 람다는 메인 스레드에서 호출된다.
     */
    var onSegmentReady: ((segmentIndex: Int, file: File) -> Unit)? = null

    private var recorder: MediaRecorder? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** 현재 세그먼트 파일 (stop() 호출 후 참조 가능) */
    var currentFile: File? = null
        private set

    /** 현재까지 시작된 세그먼트 인덱스 (0-based) */
    var segmentIndex: Int = 0
        private set

    @Volatile
    private var isRunning = false

    // ───────────────────────────────────────────────────────────────────────
    // Public API
    // ───────────────────────────────────────────────────────────────────────

    /**
     * 녹음을 시작하고 첫 번째 세그먼트 파일을 반환한다.
     * 이미 실행 중이면 기존 녹음을 중지한 뒤 재시작한다.
     */
    fun start(): File {
        if (isRunning) discard()
        isRunning = true
        segmentIndex = 0
        return beginSegment()
    }

    /**
     * 녹음을 중지하고 마지막 세그먼트 파일을 반환한다.
     * 파일이 없거나 비어 있으면 null 반환.
     * [onSegmentReady]는 호출되지 않는다 — 호출측이 직접 업로드해야 한다.
     *
     * isRunning을 먼저 false로 설정하여 mainHandler.post로 대기 중인
     * rotateSegment()가 실행되더라도 새 세그먼트를 시작하지 않고
     * onSegmentReady도 호출되지 않도록 방어한다.
     */
    fun stop(): File? {
        isRunning = false          // rotateSegment() 재진입 차단
        val stoppedFile = currentFile
        val active = recorder ?: return stoppedFile?.takeIf { it.exists() && it.length() > 0 }
        runCatching { active.stop() }
        active.release()
        recorder = null
        return stoppedFile?.takeIf { it.exists() && it.length() > 0 }
    }

    /**
     * 녹음을 즉시 중단하고 현재 파일을 삭제한다.
     */
    fun discard() {
        isRunning = false
        runCatching { recorder?.stop() }
        recorder?.release()
        recorder = null
        currentFile?.delete()
        currentFile = null
        segmentIndex = 0
    }

    // ───────────────────────────────────────────────────────────────────────
    // Internal
    // ───────────────────────────────────────────────────────────────────────

    private fun beginSegment(): File {
        val outputFile = File(
            context.cacheDir,
            "aipms-seg${segmentIndex}-${System.currentTimeMillis()}.m4a"
        )
        val mr = createMediaRecorder()
        mr.setAudioSource(MediaRecorder.AudioSource.MIC)
        mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        mr.setAudioEncodingBitRate(128_000)
        mr.setAudioSamplingRate(44_100)
        mr.setMaxDuration(segmentDurationMs)
        mr.setOutputFile(outputFile.absolutePath)
        mr.setOnInfoListener { _, what, _ ->
            if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED && isRunning) {
                // OnInfoListener 는 내부 미디어 스레드에서 호출될 수 있으므로 Main으로 이전
                mainHandler.post { rotateSegment() }
            }
        }
        mr.prepare()
        mr.start()
        recorder = mr
        currentFile = outputFile
        return outputFile
    }

    /**
     * 현재 세그먼트를 완료하고 다음 세그먼트를 시작한다.
     * 이 메서드는 메인 스레드에서 실행된다.
     */
    private fun rotateSegment() {
        val completedFile = currentFile
        val completedIndex = segmentIndex

        // 현재 녹음 중단
        runCatching { recorder?.stop() }
        recorder?.release()
        recorder = null

        // 다음 세그먼트 시작 (isRunning이 true인 동안)
        segmentIndex++
        if (isRunning) {
            beginSegment()
        }

        // 완료된 파일이 유효하고 레코더가 아직 실행 중이었을 때만 콜백 호출.
        // stop() 후 mainHandler.post 지연으로 이 코드가 실행되더라도
        // isRunning == false이므로 콜백을 건너뜀 → 이중 업로드 방지.
        if (isRunning && completedFile != null && completedFile.exists() && completedFile.length() > 0) {
            onSegmentReady?.invoke(completedIndex, completedFile)
        }
    }

    @Suppress("DEPRECATION")
    private fun createMediaRecorder(): MediaRecorder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            MediaRecorder()
        }
}
