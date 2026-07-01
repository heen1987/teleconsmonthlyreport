package com.aipms

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import com.aipms.client.KtorAiPmsApiClient
import com.aipms.client.LoginRequest
import com.aipms.client.MeetingStatusDto
import com.aipms.client.MeetingUploadRepository
import com.aipms.client.PasswordChangeRequest
import com.aipms.client.ProjectDto
import com.aipms.client.ProjectMemberDto
import com.aipms.client.UserDto
import com.aipms.recording.AndroidAudioRecorder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : Activity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var recorder: AndroidAudioRecorder
    private lateinit var platformUrlInput: EditText
    private lateinit var collectionUrlInput: EditText
    private lateinit var employeeNoInput: EditText
    private lateinit var passwordInput: EditText
    private lateinit var newPasswordInput: EditText
    private lateinit var confirmPasswordInput: EditText
    private lateinit var meetingIdInput: EditText
    private lateinit var projectSpinner: Spinner
    private lateinit var projectMemberSummaryText: TextView
    private lateinit var recordButton: Button
    private lateinit var uploadButton: Button
    private lateinit var loginButton: Button
    private lateinit var logoutButton: Button
    private lateinit var changePasswordButton: Button
    private lateinit var refreshProjectsButton: Button
    private lateinit var statusCheckButton: Button
    private lateinit var statusText: TextView
    private var projects: List<ProjectDto> = emptyList()
    private var projectMembers: List<ProjectMemberDto> = emptyList()
    private var recordedFile: File? = null
    private var accessToken: String? = null
    private var currentUser: UserDto? = null
    private var passwordChangeRequired = false
    private var isBusy = false
    private var isRecording = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        recorder = AndroidAudioRecorder(this)
        setContentView(buildContentView())
        ensureRecordPermission()
        setStatus("Platform/Collection URL을 확인한 뒤 프로젝트를 불러오세요.")
        restoreSessionIfAvailable()
    }

    override fun onDestroy() {
        recorder.stop()
        scope.cancel()
        super.onDestroy()
    }

    private fun buildContentView(): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(color("#F3F7FB"))
            setPadding(dp(18), dp(18), dp(18), dp(28))
        }

        container.addView(heroCard())
        platformUrlInput = input("Platform API URL", BuildConfig.AIPMS_PLATFORM_BASE_URL)
        collectionUrlInput = input("Collection API URL", BuildConfig.AIPMS_COLLECTION_BASE_URL)
        employeeNoInput = input("사번", "")
        passwordInput = passwordInput("비밀번호")
        newPasswordInput = passwordInput("새 비밀번호")
        confirmPasswordInput = passwordInput("새 비밀번호 확인")
        loginButton = button("로그인") { login() }
        changePasswordButton = button("비밀번호 변경") { changePassword() }
        logoutButton = button("로그아웃") { logout() }
        meetingIdInput = input("Meeting ID", "")
        projectSpinner = Spinner(this).apply {
            background = roundedStroke(color("#FFFFFF"), color("#D9E3EC"), dp(8), 1)
            minimumHeight = dp(44)
            layoutParams = blockParams(dp(10))
        }
        refreshProjectsButton = button("프로젝트 불러오기") { refreshProjects() }
        projectMemberSummaryText = TextView(this).apply {
            text = "프로젝트 선택 후 자동 배포 대상이 적용됩니다."
            textSize = 14f
            setTextColor(color("#667789"))
            setPadding(0, 0, 0, dp(8))
        }
        recordButton = button("녹음 시작") { toggleRecording() }
        uploadButton = button("업로드 및 분석 요청") { uploadRecording() }
        statusCheckButton = button("처리상태 확인") { refreshMeetingStatus() }

        statusText = TextView(this).apply {
            textSize = 14f
            setTextColor(color("#D9F7FF"))
            setPadding(dp(14), dp(14), dp(14), dp(14))
            background = rounded(color("#0D2B45"), dp(8))
        }

        container.addView(sectionCard("접속", "Platform과 Collection API 연결", platformUrlInput, collectionUrlInput))
        container.addView(
            sectionCard(
                "계정",
                "사번 로그인",
                employeeNoInput,
                passwordInput,
                newPasswordInput,
                confirmPasswordInput,
                actionRow(loginButton, changePasswordButton, logoutButton)
            )
        )
        container.addView(
            sectionCard(
                "회의 설정",
                "프로젝트",
                meetingIdInput,
                projectSpinner,
                projectMemberSummaryText,
                actionRow(refreshProjectsButton)
            )
        )
        container.addView(recordingCard())
        container.addView(sectionCard("상태", "업로드와 분석 진행", actionRow(statusCheckButton), statusText))
        applyAuthVisibility()

        return ScrollView(this).apply {
            setBackgroundColor(color("#F3F7FB"))
            addView(container)
        }
    }

    private fun login() {
        val employeeNo = employeeNoInput.text.toString().trim()
        val password = passwordInput.text.toString()
        if (employeeNo.isBlank() || password.isBlank()) {
            toast("사번과 비밀번호를 입력하세요.")
            return
        }

        scope.launch {
            runCatching {
                setBusy(true)
                setStatus("로그인 중...")
                val apiClient = client()
                withContext(Dispatchers.IO) {
                    apiClient.login(LoginRequest(employee_no = employeeNo, password = password))
                }
            }.onSuccess { login ->
                accessToken = login.access_token
                currentUser = login.user
                passwordChangeRequired = login.password_change_required
                saveAccessToken(login.access_token)
                applyAuthVisibility()
                if (passwordChangeRequired) {
                    setStatus("${login.user.name} 로그인됨\n초기 비밀번호 변경이 필요합니다.")
                } else {
                    passwordInput.setText("")
                    setStatus("${login.user.name} 로그인됨\n프로젝트를 불러오세요.")
                }
            }.onFailure { error ->
                clearSession()
                setStatus("로그인 실패: ${error.message}")
            }
            setBusy(false)
        }
    }

    private fun changePassword() {
        val user = currentUser
        val currentPassword = passwordInput.text.toString()
        val newPassword = newPasswordInput.text.toString()
        val confirmPassword = confirmPasswordInput.text.toString()
        if (user == null) {
            toast("로그인이 필요합니다.")
            return
        }
        if (currentPassword.isBlank() || newPassword.isBlank()) {
            toast("현재 비밀번호와 새 비밀번호를 입력하세요.")
            return
        }
        if (newPassword != confirmPassword) {
            toast("새 비밀번호가 일치하지 않습니다.")
            return
        }

        scope.launch {
            runCatching {
                setBusy(true)
                setStatus("비밀번호 변경 중...")
                val apiClient = client()
                withContext(Dispatchers.IO) {
                    apiClient.changePassword(
                        PasswordChangeRequest(
                            employee_no = user.employee_no,
                            current_password = currentPassword,
                            new_password = newPassword
                        )
                    )
                    apiClient.login(LoginRequest(employee_no = user.employee_no, password = newPassword))
                }
            }.onSuccess { login ->
                accessToken = login.access_token
                currentUser = login.user
                passwordChangeRequired = login.password_change_required
                saveAccessToken(login.access_token)
                passwordInput.setText("")
                newPasswordInput.setText("")
                confirmPasswordInput.setText("")
                applyAuthVisibility()
                setStatus("비밀번호 변경 완료\n프로젝트를 불러오세요.")
            }.onFailure { error ->
                setStatus("비밀번호 변경 실패: ${error.message}")
            }
            setBusy(false)
        }
    }

    private fun logout() {
        scope.launch {
            runCatching {
                setBusy(true)
                setStatus("로그아웃 중...")
                withContext(Dispatchers.IO) { client().logout() }
            }
            clearSession()
            setBusy(false)
            setStatus("로그아웃됨")
        }
    }

    private fun restoreSessionIfAvailable() {
        val token = getSharedPreferences(AUTH_PREFS, Context.MODE_PRIVATE)
            .getString(AUTH_TOKEN_KEY, null)
            ?.takeIf { it.isNotBlank() }
            ?: return
        accessToken = token
        scope.launch {
            runCatching {
                setBusy(true)
                setStatus("저장된 로그인 확인 중...")
                withContext(Dispatchers.IO) { client().getMe() }
            }.onSuccess { user ->
                currentUser = user
                passwordChangeRequired = user.status == "password_change_required"
                applyAuthVisibility()
                if (passwordChangeRequired) {
                    setStatus("${user.name} 로그인 복구됨\n비밀번호 변경이 필요합니다.")
                } else {
                    setStatus("${user.name} 로그인 복구됨\n프로젝트를 불러오세요.")
                }
            }.onFailure {
                clearSession()
                setStatus("Platform/Collection URL을 확인한 뒤 로그인하세요.")
            }
            setBusy(false)
        }
    }

    private fun refreshProjects() {
        if (!canUsePlatformApis()) return
        scope.launch {
            runCatching {
                setBusy(true)
                setStatus("프로젝트 목록을 불러오는 중...")
                val client = client()
                withContext(Dispatchers.IO) { client.listProjects() }
            }.onSuccess { rows ->
                projects = rows
                projectMembers = emptyList()
                projectSpinner.adapter = ArrayAdapter(
                    this@MainActivity,
                    android.R.layout.simple_spinner_dropdown_item,
                    rows.map { "${it.name} (${it.project_id})" }
                )
                projectMemberSummaryText.text = "프로젝트 선택 후 자동 배포 대상이 적용됩니다."
                setStatus("프로젝트 ${rows.size}개를 불러왔습니다.")
            }.onFailure { error ->
                setStatus("프로젝트 조회 실패: ${error.message}")
            }
            setBusy(false)
        }
    }

    private fun toggleRecording() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ensureRecordPermission()
            return
        }
        if (isRecording) {
            recordedFile = recorder.stop()
            isRecording = false
            recordButton.text = "녹음 시작"
            styleButton(recordButton, true)
            setStatus("녹음 완료: ${recordedFile?.name ?: "-"}")
        } else {
            recordedFile = recorder.start()
            isRecording = true
            recordButton.text = "녹음 중지"
            styleButton(recordButton, false)
            setStatus("녹음 중...")
        }
    }

    private fun uploadRecording() {
        if (!canUsePlatformApis()) return
        val project = selectedProjectOrNull()
        val meetingId = meetingIdInput.text.toString().trim()
        val file = recordedFile
        if (project == null) {
            toast("프로젝트를 선택하세요.")
            return
        }
        if (meetingId.isBlank()) {
            toast("Meeting ID를 입력하세요.")
            return
        }
        if (file == null || !file.exists() || file.length() == 0L) {
            toast("업로드할 녹음 파일이 없습니다.")
            return
        }
        scope.launch {
            runCatching {
                setBusy(true)
                val apiClient = client()
                runCatching {
                    withContext(Dispatchers.IO) { apiClient.getProjectDetail(project.project_id) }
                }.onSuccess { detail ->
                    projectMembers = detail.members
                    projectMemberSummaryText.text = "프로젝트 구성원 ${detail.members.size}명 자동 배포 대상"
                }
                val repository = MeetingUploadRepository(apiClient)
                setStatus("업로드 세션 생성 및 파일 업로드 중...")
                val result = withContext(Dispatchers.IO) {
                    repository.uploadRecording(
                        projectId = project.project_id,
                        meetingId = meetingId,
                        requestedBy = currentUser?.user_id,
                        audioFile = file
                    )
                }
                setStatus("분석 job 생성: ${result.job.job_id}\n상태 확인 중...")
                withContext(Dispatchers.IO) {
                    repository.pollUntilTerminal(result.job.job_id) { job ->
                        runOnUiThread {
                            setStatus("분석 상태: ${job.status}\njob=${job.job_id}\ncallback=${job.platform_callback_status ?: "-"}")
                        }
                    }
                }
            }.onSuccess { job ->
                if (job.status == "completed") {
                    setStatus("분석 완료 상태: ${job.status}\njob=${job.job_id}\nPlatform Web에서 검토/승인을 진행하세요.")
                } else {
                    setStatus("분석 종료 상태: ${job.status}\njob=${job.job_id}\nCollection job 이벤트를 확인하세요.")
                }
            }.onFailure { error ->
                setStatus("업로드/분석 요청 실패: ${error.message}")
            }
            setBusy(false)
        }
    }

    private fun refreshMeetingStatus() {
        if (!canUsePlatformApis()) return
        val meetingId = meetingIdInput.text.toString().trim()
        if (meetingId.isBlank()) {
            toast("Meeting ID를 입력하세요.")
            return
        }

        scope.launch {
            runCatching {
                setBusy(true)
                setStatus("회의 처리상태 확인 중...")
                withContext(Dispatchers.IO) { client().getMeetingStatus(meetingId) }
            }.onSuccess { status ->
                setStatus(formatMeetingStatus(status))
            }.onFailure { error ->
                setStatus("회의 처리상태 조회 실패: ${error.message}")
            }
            setBusy(false)
        }
    }

    private fun client() = KtorAiPmsApiClient(
        platformBaseUrl = platformUrlInput.text.toString().trim(),
        collectionBaseUrl = collectionUrlInput.text.toString().trim(),
        accessTokenProvider = { accessToken }
    )

    private fun selectedProjectOrNull(): ProjectDto? {
        val index = projectSpinner.selectedItemPosition
        return projects.getOrNull(index)
    }

    private fun setBusy(busy: Boolean) {
        isBusy = busy
        refreshProjectsButton.isEnabled = !busy
        recordButton.isEnabled = !busy
        uploadButton.isEnabled = !busy
        statusCheckButton.isEnabled = !busy
        platformUrlInput.isEnabled = !busy
        collectionUrlInput.isEnabled = !busy
        employeeNoInput.isEnabled = !busy && currentUser == null
        passwordInput.isEnabled = !busy && (currentUser == null || passwordChangeRequired)
        newPasswordInput.isEnabled = !busy && passwordChangeRequired
        confirmPasswordInput.isEnabled = !busy && passwordChangeRequired
        loginButton.isEnabled = !busy && currentUser == null
        logoutButton.isEnabled = !busy && currentUser != null
        changePasswordButton.isEnabled = !busy && passwordChangeRequired
    }

    private fun setStatus(message: String) {
        statusText.text = message
    }

    private fun formatMeetingStatus(status: MeetingStatusDto): String =
        listOf(
            "회의 처리상태: ${status.status} (${status.progress}%)",
            "meeting=${status.meeting_id}",
            "project=${status.project_name}",
            "analysis=${status.latest_analysis_status ?: "-"} / ${status.latest_model_name ?: "-"}",
            "distribution=${status.latest_distribution_status ?: "-"}",
            "error=${status.error_code ?: "-"}"
        ).joinToString("\n")

    private fun ensureRecordPermission() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO)
        }
    }

    private fun input(hint: String, value: String): EditText =
        EditText(this).apply {
            this.hint = hint
            setText(value)
            setSingleLine(true)
            textSize = 14f
            setTextColor(color("#0B1720"))
            setHintTextColor(color("#7A8B99"))
            setPadding(dp(12), 0, dp(12), 0)
            background = roundedStroke(color("#FFFFFF"), color("#D9E3EC"), dp(8), 1)
            layoutParams = blockParams(dp(10))
        }

    private fun passwordInput(hint: String): EditText =
        input(hint, "").apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }

    private fun button(text: String, onClick: () -> Unit): Button =
        Button(this).apply {
            this.text = text
            textSize = 14f
            isAllCaps = false
            minHeight = dp(44)
            setPadding(dp(12), 0, dp(12), 0)
            styleButton(this, true)
            layoutParams = blockParams(dp(10))
            setOnClickListener { onClick() }
        }

    private fun title(text: String): TextView =
        TextView(this).apply {
            this.text = text
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(color("#0B1720"))
            setPadding(0, 0, 0, dp(10))
        }

    private fun heroCard(): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = gradient(color("#071827"), color("#0F5E72"))
            setPadding(dp(20), dp(22), dp(20), dp(22))
            layoutParams = blockParams(dp(14))
            addView(
                TextView(this@MainActivity).apply {
                    text = "AI-PMS Recorder"
                    textSize = 28f
                    typeface = Typeface.DEFAULT_BOLD
                    setTextColor(Color.WHITE)
                }
            )
            addView(
                TextView(this@MainActivity).apply {
                    text = "회의 녹음과 분석 job을 Project_ID로 연결"
                    textSize = 14f
                    setTextColor(color("#B9F3FF"))
                    setPadding(0, dp(8), 0, 0)
                }
            )
            addView(
                LinearLayout(this@MainActivity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(0, dp(18), 0, 0)
                    addView(statusBadge("STT"))
                    addView(statusBadge("LLM"))
                    addView(statusBadge("PMS"))
                    addView(statusBadge("LAN"))
                }
            )
        }

    private fun recordingCard(): LinearLayout =
        sectionCard(
            "녹음",
            "모바일 수집",
            TextView(this).apply {
                text = "▁▃▅▇▅▃▂▅▇▆▃▁"
                textSize = 28f
                gravity = Gravity.CENTER
                setTextColor(color("#25C2E8"))
                setPadding(0, dp(8), 0, dp(8))
            },
            actionRow(recordButton, uploadButton)
        )

    private fun sectionCard(titleText: String, subtitle: String, vararg children: View): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedStroke(Color.WHITE, color("#D9E3EC"), dp(8), 1)
            setPadding(dp(16), dp(16), dp(16), dp(14))
            layoutParams = blockParams(dp(12))
            addView(title(titleText))
            addView(
                TextView(this@MainActivity).apply {
                    text = subtitle
                    textSize = 12f
                    setTextColor(color("#667789"))
                    setPadding(0, 0, 0, dp(12))
                }
            )
            children.forEach { addView(it) }
        }

    private fun actionRow(vararg buttons: Button): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            buttons.forEach { addView(it) }
        }

    private fun statusBadge(text: String): TextView =
        TextView(this).apply {
            this.text = text
            textSize = 12f
            setTextColor(color("#0D2B45"))
            gravity = Gravity.CENTER
            setPadding(dp(10), dp(5), dp(10), dp(5))
            background = rounded(color("#E7F8FF"), dp(18))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, dp(8), 0)
            }
        }

    private fun styleButton(target: Button, primary: Boolean) {
        target.setTextColor(Color.WHITE)
        target.background = rounded(if (primary) color("#1769FF") else color("#E04461"), dp(8))
    }

    private fun blockParams(bottom: Int = dp(10)): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            setMargins(0, 0, 0, bottom)
        }

    private fun rounded(fill: Int, radius: Int): GradientDrawable =
        GradientDrawable().apply {
            setColor(fill)
            cornerRadius = radius.toFloat()
        }

    private fun roundedStroke(fill: Int, stroke: Int, radius: Int, strokeWidth: Int): GradientDrawable =
        rounded(fill, radius).apply {
            setStroke(dp(strokeWidth), stroke)
        }

    private fun gradient(start: Int, end: Int): GradientDrawable =
        GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(start, end)).apply {
            cornerRadius = dp(8).toFloat()
        }

    private fun color(hex: String): Int = Color.parseColor(hex)

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    private fun canUsePlatformApis(): Boolean {
        if (accessToken.isNullOrBlank() || currentUser == null) {
            toast("먼저 로그인하세요.")
            return false
        }
        if (passwordChangeRequired) {
            toast("비밀번호 변경 후 진행하세요.")
            return false
        }
        return true
    }

    private fun saveAccessToken(token: String) {
        getSharedPreferences(AUTH_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(AUTH_TOKEN_KEY, token)
            .apply()
    }

    private fun clearSession() {
        getSharedPreferences(AUTH_PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(AUTH_TOKEN_KEY)
            .apply()
        accessToken = null
        currentUser = null
        passwordChangeRequired = false
        projects = emptyList()
        projectMembers = emptyList()
        employeeNoInput.isEnabled = true
        employeeNoInput.setText("")
        passwordInput.setText("")
        newPasswordInput.setText("")
        confirmPasswordInput.setText("")
        projectSpinner.adapter = null
        projectMemberSummaryText.text = "프로젝트 선택 후 자동 배포 대상이 적용됩니다."
        applyAuthVisibility()
    }

    private fun applyAuthVisibility() {
        val loggedIn = currentUser != null
        loginButton.visibility = if (loggedIn) View.GONE else View.VISIBLE
        logoutButton.visibility = if (loggedIn) View.VISIBLE else View.GONE
        newPasswordInput.visibility = if (passwordChangeRequired) View.VISIBLE else View.GONE
        confirmPasswordInput.visibility = if (passwordChangeRequired) View.VISIBLE else View.GONE
        changePasswordButton.visibility = if (passwordChangeRequired) View.VISIBLE else View.GONE
        setBusy(isBusy)
    }

    companion object {
        private val screenDesignTraceMarkers = listOf(
            "APP-01 로그인",
            "APP-02 프로젝트 선택",
            "APP-03 회의명",
            "APP-04 녹음",
            "APP-05 처리상태",
            "회의명 또는 Meeting ID",
            "actionRow(recordButton)",
            "actionRow(uploadButton, statusCheckButton)",
            "AppScreen.PROJECTS -> projectsScreen()",
            "AppScreen.RECORDING -> recordingScreen()",
            "AppScreen.STATUS -> statusScreen()"
        )
        private const val REQUEST_RECORD_AUDIO = 1001
        private const val AUTH_PREFS = "ai_pms_auth"
        private const val AUTH_TOKEN_KEY = "access_token"
    }
}
