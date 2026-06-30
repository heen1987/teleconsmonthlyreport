package com.aipms.client

interface AiPmsApiClient {
    suspend fun login(payload: LoginRequest): LoginOut
    suspend fun getMe(): UserDto
    suspend fun changePassword(payload: PasswordChangeRequest): PasswordChangeOut
    suspend fun logout()
    suspend fun listProjects(): List<ProjectDto>
    suspend fun getProjectDetail(projectId: String): ProjectDetailDto
    suspend fun getMeetingStatus(meetingId: String): MeetingStatusDto
    suspend fun createUploadSession(payload: UploadSessionCreate): UploadSessionOut
    suspend fun uploadAudioFile(sessionId: String, uploadToken: String, filePath: String): AudioAssetOut
    suspend fun registerAudioAsset(payload: AudioAssetCreate): AudioAssetOut
    suspend fun createAnalysisJob(payload: AnalysisJobCreate): AnalysisJobOut
    suspend fun getAnalysisJob(jobId: String): AnalysisJobOut
}
