package com.aipms.client

import kotlinx.coroutines.delay
import java.io.File
import java.security.MessageDigest
import kotlin.time.Duration
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Duration.Companion.seconds

class MeetingUploadRepository(
    private val apiClient: AiPmsApiClient
) {
    suspend fun uploadRecording(
        projectId: String,
        meetingId: String,
        requestedBy: String?,
        audioFile: File,
        language: String = "ko",
        priority: Int = 100
    ): RecordingUploadResult {
        val session = apiClient.createUploadSession(
            UploadSessionCreate(
                project_id = projectId,
                meeting_id = meetingId,
                requested_by = requestedBy,
                file_name = audioFile.name,
                content_type = KtorAiPmsApiClient.audioContentType(audioFile.name),
                expected_size_bytes = audioFile.length(),
                checksum_sha256 = sha256Hex(audioFile)
            )
        )
        val uploadToken = requireNotNull(session.upload_token) {
            "Collection API did not return an upload token"
        }
        val asset = apiClient.uploadAudioFile(session.session_id, uploadToken, audioFile.absolutePath)
        val job = apiClient.createAnalysisJob(
            AnalysisJobCreate(
                session_id = session.session_id,
                asset_id = asset.asset_id,
                priority = priority,
                language = language
            )
        )
        return RecordingUploadResult(session, asset, job)
    }

    suspend fun pollUntilTerminal(
        jobId: String,
        interval: Duration = 3.seconds,
        timeout: Duration = 7.minutes,
        onStatus: (AnalysisJobOut) -> Unit = {}
    ): AnalysisJobOut {
        val deadline = System.currentTimeMillis() + timeout.inWholeMilliseconds
        while (System.currentTimeMillis() < deadline) {
            val job = apiClient.getAnalysisJob(jobId)
            onStatus(job)
            if (job.status in TERMINAL_JOB_STATUSES) {
                return job
            }
            delay(interval)
        }
        error("Timed out waiting for analysis job $jobId")
    }

    private fun sha256Hex(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }

    companion object {
        private val TERMINAL_JOB_STATUSES = setOf("completed", "failed", "cancelled")
    }
}
