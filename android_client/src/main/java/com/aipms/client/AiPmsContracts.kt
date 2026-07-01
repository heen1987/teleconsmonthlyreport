package com.aipms.client

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

@Serializable
data class UserDto(
    val user_id: String,
    val employee_no: String,
    val name: String,
    val email: String? = null,
    val role: String,
    val status: String
)

@Serializable
data class LoginRequest(
    val employee_no: String,
    val password: String
)

@Serializable
data class LoginOut(
    val access_token: String,
    val token_type: String = "bearer",
    val expires_at: String,
    val user: UserDto,
    val password_change_required: Boolean
)

@Serializable
data class PasswordChangeRequest(
    val employee_no: String,
    val current_password: String,
    val new_password: String
)

@Serializable
data class PasswordChangeOut(
    val employee_no: String,
    val status: String
)

@Serializable
data class ProjectDto(
    val project_id: String,
    val name: String,
    val pm_user_id: String?,
    val status: String
)

@Serializable
data class ProjectMemberDto(
    val project_id: String,
    val user_id: String,
    val employee_no: String,
    val name: String,
    val project_role: String
)

@Serializable
data class ProjectDetailDto(
    val project_id: String,
    val name: String,
    val pm_user_id: String?,
    val status: String,
    val members: List<ProjectMemberDto> = emptyList()
)

@Serializable
data class MeetingStatusDto(
    val screen_id: String = "A-004",
    val meeting_id: String,
    val project_id: String,
    val project_name: String,
    val title: String,
    val status: String,
    val progress: Int,
    val error_code: String? = null,
    val latest_analysis_id: String? = null,
    val latest_analysis_status: String? = null,
    val latest_model_name: String? = null,
    val latest_distribution_id: String? = null,
    val latest_distribution_status: String? = null,
    val created_at: String
)

@Serializable
data class UploadSessionCreate(
    val project_id: String,
    val meeting_id: String,
    val requested_by: String?,
    val file_name: String?,
    val content_type: String?,
    val expected_size_bytes: Long?,
    val checksum_sha256: String?,
    val expires_at: String? = null
)

@Serializable
data class UploadSessionOut(
    val session_id: String,
    val project_id: String,
    val meeting_id: String,
    val status: String,
    val upload_token: String?,
    val expires_at: String?
)

@Serializable
data class AudioAssetCreate(
    val session_id: String,
    val storage_uri: String?,
    val file_name: String?,
    val content_type: String?,
    val size_bytes: Long?,
    val checksum_sha256: String?,
    val duration_seconds: Double?
)

@Serializable
data class AudioAssetOut(
    val asset_id: String,
    val session_id: String,
    val project_id: String,
    val meeting_id: String,
    val status: String,
    val storage_uri: String?,
    val file_name: String?,
    val content_type: String?,
    val size_bytes: Long?,
    val checksum_sha256: String?,
    val duration_seconds: Double?
)

@Serializable
data class AnalysisJobCreate(
    val session_id: String,
    val asset_id: String?,
    val priority: Int = 100,
    val transcript_text: String? = null,
    val language: String = "ko"
)

@Serializable
data class AnalysisJobOut(
    val job_id: String,
    val session_id: String?,
    val asset_id: String?,
    val project_id: String,
    val meeting_id: String,
    val transcript_text: String?,
    val language: String,
    val status: String,
    val claimed_by: String?,
    val lease_expires_at: String?,
    val model_name: String?,
    val result_json: JsonObject?,
    val attempt_count: Int,
    val max_attempts: Int,
    val platform_callback_status: String? = null,
    val platform_callback_attempt_count: Int? = null,
    val platform_callback_max_attempts: Int? = null,
    val platform_callback_next_attempt_at: String? = null,
    val platform_callback_last_attempt_at: String? = null,
    val platform_callback_completed_at: String? = null,
    val platform_callback_last_error: String? = null
)

data class RecordingUploadResult(
    val session: UploadSessionOut,
    val asset: AudioAssetOut,
    val job: AnalysisJobOut
)
