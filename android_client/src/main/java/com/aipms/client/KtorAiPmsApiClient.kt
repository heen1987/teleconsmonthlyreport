package com.aipms.client

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.forms.formData
import io.ktor.client.request.forms.submitFormWithBinaryData
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import java.io.File

class KtorAiPmsApiClient(
    private val platformBaseUrl: String,
    private val collectionBaseUrl: String,
    private val accessTokenProvider: () -> String? = { null },
    private val httpClient: HttpClient = defaultHttpClient()
) : AiPmsApiClient {
    override suspend fun login(payload: LoginRequest): LoginOut =
        httpClient.post("${platformBaseUrl.trimEnd('/')}/users/login") {
            contentType(ContentType.Application.Json)
            setBody(payload)
        }.body()

    override suspend fun getMe(): UserDto =
        httpClient.get("${platformBaseUrl.trimEnd('/')}/users/me") {
            bearerAuthIfAvailable()
        }.body()

    override suspend fun changePassword(payload: PasswordChangeRequest): PasswordChangeOut =
        httpClient.post("${platformBaseUrl.trimEnd('/')}/users/password/change") {
            bearerAuthIfAvailable()
            contentType(ContentType.Application.Json)
            setBody(payload)
        }.body()

    override suspend fun logout() {
        httpClient.post("${platformBaseUrl.trimEnd('/')}/users/logout") {
            bearerAuthIfAvailable()
        }
    }

    override suspend fun listProjects(): List<ProjectDto> =
        httpClient.get("${platformBaseUrl.trimEnd('/')}/projects") {
            bearerAuthIfAvailable()
        }.body()

    override suspend fun getProjectDetail(projectId: String): ProjectDetailDto =
        httpClient.get("${platformBaseUrl.trimEnd('/')}/projects/$projectId/detail") {
            bearerAuthIfAvailable()
        }.body()

    override suspend fun getMeetingStatus(meetingId: String): MeetingStatusDto =
        httpClient.get("${platformBaseUrl.trimEnd('/')}/meetings/$meetingId/status") {
            bearerAuthIfAvailable()
        }.body()

    override suspend fun createUploadSession(payload: UploadSessionCreate): UploadSessionOut =
        httpClient.post("${collectionBaseUrl.trimEnd('/')}/upload-sessions") {
            contentType(ContentType.Application.Json)
            setBody(payload)
        }.body()

    override suspend fun uploadAudioFile(
        sessionId: String,
        uploadToken: String,
        filePath: String
    ): AudioAssetOut {
        val file = File(filePath)
        return httpClient.submitFormWithBinaryData(
            url = "${collectionBaseUrl.trimEnd('/')}/upload-sessions/$sessionId/audio-file",
            formData = formData {
                append(
                    "file",
                    file.readBytes(),
                    Headers.build {
                        append(HttpHeaders.ContentDisposition, "filename=\"${file.name}\"")
                        append(HttpHeaders.ContentType, audioContentType(file.name))
                    }
                )
            }
        ) {
            header("X-Upload-Token", uploadToken)
        }.body()
    }

    override suspend fun registerAudioAsset(payload: AudioAssetCreate): AudioAssetOut =
        httpClient.post("${collectionBaseUrl.trimEnd('/')}/audio-assets") {
            contentType(ContentType.Application.Json)
            setBody(payload)
        }.body()

    override suspend fun createAnalysisJob(payload: AnalysisJobCreate): AnalysisJobOut =
        httpClient.post("${collectionBaseUrl.trimEnd('/')}/analysis-jobs") {
            contentType(ContentType.Application.Json)
            setBody(payload)
        }.body()

    override suspend fun getAnalysisJob(jobId: String): AnalysisJobOut =
        httpClient.get("${collectionBaseUrl.trimEnd('/')}/analysis-jobs/$jobId").body()

    private fun io.ktor.client.request.HttpRequestBuilder.bearerAuthIfAvailable() {
        accessTokenProvider()?.takeIf { it.isNotBlank() }?.let { token ->
            header(HttpHeaders.Authorization, "Bearer $token")
        }
    }

    companion object {
        fun defaultHttpClient() = HttpClient(Android) {
            install(ContentNegotiation) {
                json(
                    Json {
                        ignoreUnknownKeys = true
                        explicitNulls = false
                    }
                )
            }
            expectSuccess = true
        }

        fun audioContentType(fileName: String): String {
            return when (fileName.substringAfterLast('.', "").lowercase()) {
                "wav" -> "audio/wav"
                "m4a", "mp4" -> "audio/mp4"
                "mp3" -> "audio/mpeg"
                "ogg" -> "audio/ogg"
                else -> "application/octet-stream"
            }
        }
    }
}
