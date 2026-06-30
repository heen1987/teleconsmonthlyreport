package com.aipms

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
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
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : Activity() {
    @Serializable
    private data class AndroidUpdateManifest(
        val enabled: Boolean = true,
        val package_name: String = "com.aipms",
        val latest_version_code: Int = 1,
        val latest_version_name: String = "0.1.0",
        val apk_url: String? = null,
        val sha256: String? = null,
        val mandatory: Boolean = false,
        val release_notes: String = ""
    )

    private enum class AppScreen {
        HOME,
        PROJECTS,
        RECORDING,
        STATUS,
        ACCOUNT
    }

    private val screenDesignTraceMarkers = listOf(
        "APP-01 로그인",
        "APP-02 프로젝트 선택",
        "APP-03 회의명",
        "APP-04 녹음",
        "APP-05 처리상태"
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var recorder: AndroidAudioRecorder
    private lateinit var contentHost: FrameLayout
    private lateinit var toolbarTitle: TextView
    private lateinit var toolbarSubtitle: TextView
    private lateinit var toolbarUser: TextView
    private lateinit var statusText: TextView
    private lateinit var projectSummaryText: TextView
    private lateinit var recordingStateText: TextView
    private lateinit var updateStatusText: TextView

    private lateinit var platformUrlInput: EditText
    private lateinit var collectionUrlInput: EditText
    private lateinit var employeeNoInput: EditText
    private lateinit var passwordInput: EditText
    private lateinit var newPasswordInput: EditText
    private lateinit var confirmPasswordInput: EditText
    private lateinit var requestedByInput: EditText
    private lateinit var meetingIdInput: EditText
    private lateinit var projectSpinner: Spinner
    private lateinit var projectMemberContainer: LinearLayout

    private lateinit var recordButton: Button
    private lateinit var uploadButton: Button
    private lateinit var loginButton: Button
    private lateinit var logoutButton: Button
    private lateinit var changePasswordButton: Button
    private lateinit var refreshProjectsButton: Button
    private lateinit var refreshProjectMembersButton: Button
    private lateinit var statusCheckButton: Button
    private lateinit var checkUpdateButton: Button
    private lateinit var openUpdateButton: Button

    private var currentScreen = AppScreen.HOME
    private var pendingUpdate: AndroidUpdateManifest? = null
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
        setStatus("로그인 필요")
        restoreSessionIfAvailable()
    }

    override fun onDestroy() {
        recorder.stop()
        scope.cancel()
        super.onDestroy()
    }

    private fun buildContentView(): View {
        createControls()

        val shell = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(color("#F4F7FA"))
        }
        shell.addView(topBar())

        contentHost = FrameLayout(this).apply {
            setBackgroundColor(color("#F4F7FA"))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }
        shell.addView(contentHost)

        shell.addView(statusBar())
        showScreen(AppScreen.HOME)
        applyAuthVisibility()
        return shell
    }

    private fun createControls() {
        platformUrlInput = input("Platform API URL", BuildConfig.AIPMS_PLATFORM_BASE_URL)
        collectionUrlInput = input("Collection API URL", BuildConfig.AIPMS_COLLECTION_BASE_URL)
        employeeNoInput = input("사번", "")
        passwordInput = passwordInput("비밀번호")
        newPasswordInput = passwordInput("새 비밀번호")
        confirmPasswordInput = passwordInput("새 비밀번호 확인")
        requestedByInput = input("요청자 ID", "system")
        meetingIdInput = input("회의명 또는 Meeting ID", "")

        loginButton = button("로그인") { login() }
        changePasswordButton = button("비밀번호 변경") { changePassword() }
        logoutButton = button("로그아웃") { logout() }
        refreshProjectsButton = button("프로젝트 불러오기") { refreshProjects() }
        refreshProjectMembersButton = button("구성원 확인") { refreshProjectMembers() }
        recordButton = button("녹음 시작") { toggleRecording() }
        uploadButton = button("업로드 및 분석 요청") { uploadRecording() }
        statusCheckButton = button("처리상태 확인") { refreshMeetingStatus() }
        checkUpdateButton = button("업데이트 확인") { checkForAppUpdate(silent = false) }
        openUpdateButton = button("설치 페이지 열기") { openPendingUpdate() }

        projectSpinner = Spinner(this).apply {
            background = roundedStroke(Color.WHITE, color("#D7E0EA"), dp(10), 1)
            minimumHeight = dp(48)
            layoutParams = blockParams(dp(10))
        }
        projectMemberContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(6), 0, 0)
        }
        renderProjectMembers(emptyList(), "")

        projectSummaryText = infoBox("프로젝트 없음")
        recordingStateText = recordingMeter("녹음 대기", "00:00:00", "프로젝트 선택 후 녹음")
        updateStatusText = infoBox("")
    }

    private fun topBar(): View =
        LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(12))
            setBackgroundColor(Color.WHITE)
            elevation = dp(4).toFloat()

            addView(
                TextView(this@MainActivity).apply {
                    text = "M"
                    textSize = 20f
                    typeface = Typeface.DEFAULT_BOLD
                    gravity = Gravity.CENTER
                    setTextColor(Color.WHITE)
                    background = rounded(color("#0496A6"), dp(8))
                    layoutParams = LinearLayout.LayoutParams(dp(38), dp(38)).apply {
                        setMargins(0, 0, dp(10), 0)
                    }
                }
            )
            addView(
                LinearLayout(this@MainActivity).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                    toolbarTitle = TextView(this@MainActivity).apply {
                        text = "MEETFLOW"
                        textSize = 20f
                        typeface = Typeface.DEFAULT_BOLD
                        setTextColor(color("#06306B"))
                    }
                    toolbarSubtitle = TextView(this@MainActivity).apply {
                        text = "AI-PMS Recorder"
                        textSize = 11f
                        setTextColor(color("#667789"))
                    }
                    addView(toolbarTitle)
                    addView(toolbarSubtitle)
                }
            )
            toolbarUser = TextView(this@MainActivity).apply {
                text = "로그인 필요"
                textSize = 12f
                gravity = Gravity.CENTER
                setTextColor(color("#31506B"))
                setPadding(dp(10), dp(7), dp(10), dp(7))
                background = rounded(color("#EEF6FF"), dp(18))
            }
            addView(toolbarUser)
        }

    private fun statusBar(): View {
        statusText = TextView(this).apply {
            textSize = 13f
            setTextColor(color("#163247"))
            setLineSpacing(3f, 1.0f)
            maxLines = 3
            setPadding(dp(14), dp(10), dp(14), dp(10))
            background = roundedStroke(color("#F8FBFF"), color("#D7E0EA"), 0, 1)
        }
        return statusText
    }

    private fun showScreen(screen: AppScreen) {
        currentScreen = screen
        toolbarTitle.text = when (screen) {
            AppScreen.HOME -> "MEETFLOW"
            AppScreen.PROJECTS -> "프로젝트 선택"
            AppScreen.RECORDING -> "회의 녹음"
            AppScreen.STATUS -> "처리 상태"
            AppScreen.ACCOUNT -> "계정"
        }
        toolbarSubtitle.text = when (screen) {
            AppScreen.HOME -> "AI-PMS Recorder"
            AppScreen.PROJECTS -> "Project_ID 기준 업로드 준비"
            AppScreen.RECORDING -> "녹음·업로드·분석 요청"
            AppScreen.STATUS -> "Meeting_ID 기준 상태 조회"
            AppScreen.ACCOUNT -> "로그인·비밀번호·서버 설정"
        }
        contentHost.removeAllViews()
        contentHost.addView(
            when (screen) {
                AppScreen.HOME -> homeScreen()
                AppScreen.PROJECTS -> projectsScreen()
                AppScreen.RECORDING -> recordingScreen()
                AppScreen.STATUS -> statusScreen()
                AppScreen.ACCOUNT -> accountScreen()
            }
        )
    }

    private fun homeScreen(): View =
        screenScroll(
            navigationPanel(),
            recorderCard(),
            projectSelectionCard(),
            accountCard(),
            serverCard()
        )

    private fun projectsScreen(): View =
        screenScroll(
            navigationPanel(),
            projectSelectionCard()
        )

    private fun recordingScreen(): View =
        screenScroll(
            navigationPanel(),
            recorderCard(),
            projectSelectionCard()
        )

    private fun statusScreen(): View =
        screenScroll(
            navigationPanel(),
            statusCard()
        )

    private fun accountScreen(): View =
        screenScroll(
            navigationPanel(),
            accountCard(),
            serverCard()
        )

    private fun navigationPanel(): LinearLayout =
        sectionCard(
            "이동",
            "",
            actionRow(
                navigationButton("홈", AppScreen.HOME),
                navigationButton("프로젝트", AppScreen.PROJECTS),
                navigationButton("녹음", AppScreen.RECORDING),
                navigationButton("상태", AppScreen.STATUS),
                navigationButton("계정", AppScreen.ACCOUNT)
            )
        )

    private fun navigationButton(label: String, screen: AppScreen): Button =
        button(label) { showScreen(screen) }.apply {
            isEnabled = currentScreen != screen && !isBusy
            background = rounded(if (currentScreen == screen) color("#0496A6") else color("#063D87"), dp(10))
        }

    private fun projectSelectionCard(): LinearLayout =
        sectionCard(
            "프로젝트 선택",
            "프로젝트를 선택하면 구성원 이메일이 자동 배포 대상이 됩니다.",
            projectSpinner,
            actionRow(refreshProjectsButton, refreshProjectMembersButton),
            projectSummaryText,
            projectMemberContainer
        )

    private fun accountCard(): LinearLayout =
        sectionCard(
            "계정",
            "",
            employeeNoInput,
            passwordInput,
            newPasswordInput,
            confirmPasswordInput,
            actionRow(loginButton, changePasswordButton, logoutButton)
        )

    private fun serverCard(): LinearLayout =
        sectionCard(
            "서버",
            "",
            platformUrlInput,
            collectionUrlInput
        )

    private fun statusCard(): LinearLayout =
        sectionCard(
            "처리 상태",
            "Meeting_ID 기준으로 Platform API 처리 결과를 조회합니다.",
            meetingIdInput,
            actionRow(statusCheckButton),
            recordingStateText
        )

    private fun recorderCard(): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedStroke(Color.WHITE, color("#CFDCE9"), dp(14), 1)
            val padding = if (isTabletLayout()) dp(20) else dp(16)
            setPadding(padding, dp(16), padding, dp(16))
            layoutParams = blockParams(dp(12))
            addView(
                TextView(this@MainActivity).apply {
                    text = "회의 녹음"
                    textSize = 20f
                    typeface = Typeface.DEFAULT_BOLD
                    setTextColor(color("#06306B"))
                    setPadding(0, 0, 0, dp(4))
                }
            )
            addView(
                TextView(this@MainActivity).apply {
                    text = "프로젝트 기준 녹음·업로드"
                    textSize = 12f
                    typeface = Typeface.DEFAULT_BOLD
                    setTextColor(color("#0496A6"))
                    setPadding(0, 0, 0, dp(12))
                }
            )
            attachChild(meetingIdInput)
            attachChild(recordingStateText)
            attachChild(actionRow(recordButton))
            attachChild(actionRow(uploadButton, statusCheckButton))
        }

    private fun checkForAppUpdate(silent: Boolean) {
        if (!isInternetAvailable()) {
            if (!silent) {
                updateStatusText.text = "인터넷 연결이 없어 업데이트를 확인할 수 없습니다."
                setStatus("인터넷 연결 후 다시 확인하세요.")
            }
            return
        }

        scope.launch {
            runCatching {
                if (!silent) setStatus("앱 업데이트 확인 중...")
                updateStatusText.text = "서버에서 최신 앱 정보를 확인하는 중..."
                withContext(Dispatchers.IO) { fetchAndroidUpdateManifest() }
            }.onSuccess { manifest ->
                handleUpdateManifest(manifest, silent)
            }.onFailure { error ->
                pendingUpdate = null
                updateStatusText.text = "업데이트 확인 실패\n${error.message}"
                applyAuthVisibility()
                if (!silent) setStatus("업데이트 확인 실패: ${error.message}")
            }
        }
    }

    private fun fetchAndroidUpdateManifest(): AndroidUpdateManifest {
        val baseUrl = platformUrlInput.text.toString().trim().trimEnd('/')
        require(baseUrl.isNotBlank()) { "Platform API URL이 비어 있습니다." }
        val connection = URL("$baseUrl/mobile/android/update.json").openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.setRequestProperty("Accept", "application/json")
            val statusCode = connection.responseCode
            if (statusCode !in 200..299) {
                error("manifest 응답 코드 $statusCode")
            }
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            UPDATE_JSON.decodeFromString(AndroidUpdateManifest.serializer(), body)
        } finally {
            connection.disconnect()
        }
    }

    private fun handleUpdateManifest(manifest: AndroidUpdateManifest, silent: Boolean) {
        if (!manifest.enabled) {
            pendingUpdate = null
            updateStatusText.text = "서버 업데이트 기능이 비활성화되어 있습니다."
            applyAuthVisibility()
            return
        }
        if (manifest.package_name != packageName) {
            pendingUpdate = null
            updateStatusText.text = "업데이트 package가 현재 앱과 다릅니다.\nserver=${manifest.package_name}\napp=$packageName"
            applyAuthVisibility()
            if (!silent) setStatus("업데이트 package가 현재 앱과 다릅니다.")
            return
        }
        if (manifest.latest_version_code <= BuildConfig.VERSION_CODE) {
            pendingUpdate = null
            updateStatusText.text = "현재 최신 버전입니다.\n현재 ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
            applyAuthVisibility()
            if (!silent) setStatus("현재 앱이 최신 버전입니다.")
            return
        }
        if (manifest.apk_url.isNullOrBlank()) {
            pendingUpdate = null
            updateStatusText.text = "새 버전이 있지만 APK URL이 설정되지 않았습니다.\n서버 ANDROID_UPDATE_APK_URL을 확인하세요."
            applyAuthVisibility()
            if (!silent) setStatus("새 버전의 APK URL이 없습니다.")
            return
        }

        pendingUpdate = manifest
        updateStatusText.text = buildString {
            append("새 버전 사용 가능\n")
            append("현재 ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE}) → ")
            append("${manifest.latest_version_name} (${manifest.latest_version_code})")
            if (manifest.mandatory) append("\n필수 업데이트")
            if (manifest.release_notes.isNotBlank()) append("\n${manifest.release_notes}")
            if (!manifest.sha256.isNullOrBlank()) append("\nSHA-256: ${manifest.sha256}")
        }
        applyAuthVisibility()
        setStatus("새 앱 버전 ${manifest.latest_version_name}이 있습니다. 계정/설정에서 설치 페이지를 여세요.")
    }

    private fun openPendingUpdate() {
        val manifest = pendingUpdate
        val apkUrl = manifest?.apk_url?.takeIf { it.isNotBlank() }
        if (apkUrl == null) {
            toast("설치할 업데이트가 없습니다.")
            return
        }

        if (!packageManager.canRequestPackageInstalls()) {
            runCatching {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")
                    )
                )
            }
            setStatus("이 앱의 APK 설치 허용을 켠 뒤 설치 페이지 열기를 다시 누르세요.")
            return
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(apkUrl)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(intent)
            setStatus("APK 설치 페이지를 열었습니다. Android 설치 확인 화면에서 업데이트를 승인하세요.")
        } catch (error: ActivityNotFoundException) {
            setStatus("APK URL을 열 앱을 찾지 못했습니다: ${error.message}")
        }
    }

    private fun isInternetAvailable(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
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
                requestedByInput.setText(login.user.user_id)
                applyAuthVisibility()
                if (passwordChangeRequired) {
                    setStatus("${login.user.name} 로그인")
                    showScreen(AppScreen.ACCOUNT)
                } else {
                    passwordInput.setText("")
                    setStatus("${login.user.name} 로그인")
                    showScreen(AppScreen.PROJECTS)
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
                requestedByInput.setText(login.user.user_id)
                passwordInput.setText("")
                newPasswordInput.setText("")
                confirmPasswordInput.setText("")
                applyAuthVisibility()
                setStatus("비밀번호 변경 완료")
                showScreen(AppScreen.PROJECTS)
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
            setStatus("로그아웃되었습니다.")
            showScreen(AppScreen.ACCOUNT)
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
                requestedByInput.setText(user.user_id)
                applyAuthVisibility()
                if (passwordChangeRequired) {
                    setStatus("${user.name} 로그인")
                    showScreen(AppScreen.ACCOUNT)
                } else {
                    setStatus("${user.name} 로그인")
                    showScreen(AppScreen.PROJECTS)
                }
            }.onFailure {
                clearSession()
                setStatus("로그인 필요")
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
                withContext(Dispatchers.IO) { client().listProjects() }
            }.onSuccess { rows ->
                projects = rows
                projectMembers = emptyList()
                projectSpinner.adapter = ArrayAdapter(
                    this@MainActivity,
                    android.R.layout.simple_spinner_dropdown_item,
                    rows.map { "${it.name} (${it.project_id})" }
                )
                renderProjectMembers(emptyList(), "프로젝트를 선택한 뒤 구성원을 확인하세요.")
                updateProjectSummary()
                setStatus("프로젝트 ${rows.size}개를 불러왔습니다.")
            }.onFailure { error ->
                setStatus("프로젝트 조회 실패: ${error.message}")
            }
            setBusy(false)
        }
    }

    private fun refreshProjectMembers() {
        if (!canUsePlatformApis()) return
        val project = selectedProjectOrNull()
        if (project == null) {
            toast("프로젝트를 먼저 불러오세요.")
            return
        }

        scope.launch {
            runCatching {
                setBusy(true)
                setStatus("프로젝트 구성원을 불러오는 중...")
                withContext(Dispatchers.IO) { client().getProjectDetail(project.project_id) }
            }.onSuccess { detail ->
                projectMembers = detail.members
                renderProjectMembers(detail.members)
                updateProjectSummary()
                setStatus("자동 배포 대상 ${detail.members.size}명을 확인했습니다.")
            }.onFailure { error ->
                projectMembers = emptyList()
                renderProjectMembers(emptyList(), "구성원 조회 실패")
                setStatus("구성원 조회 실패: ${error.message}")
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
            setRecordingMeter("녹음 완료", "저장 완료", recordedFile?.name ?: "-")
            setStatus("녹음 완료: ${recordedFile?.name ?: "-"}")
        } else {
            recordedFile = recorder.start()
            isRecording = true
            recordButton.text = "녹음 중지"
            styleButton(recordButton, false)
            setRecordingMeter("녹음 중", "00:00:00", "마이크 입력 중")
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
                val repository = MeetingUploadRepository(apiClient)
                setStatus("업로드 세션 생성 및 파일 업로드 중...")
                val result = withContext(Dispatchers.IO) {
                    repository.uploadRecording(
                        projectId = project.project_id,
                        meetingId = meetingId,
                        requestedBy = requestedByInput.text.toString().trim().ifBlank { null },
                        audioFile = file
                    )
                }
                setStatus("분석 job 생성: ${result.job.job_id}. 상태 확인 중...")
                withContext(Dispatchers.IO) {
                    repository.pollUntilTerminal(result.job.job_id) { job ->
                        runOnUiThread {
                            setStatus("분석 상태: ${job.status}\njob=${job.job_id}")
                        }
                    }
                }
            }.onSuccess { job ->
                if (job.status == "completed") {
                    setRecordingMeter("분석 완료", "100%", job.job_id)
                    setStatus("분석 완료")
                } else {
                    setStatus("분석 종료: ${job.status}")
                }
                showScreen(AppScreen.STATUS)
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
                setStatus("회의 처리 상태 조회 중...")
                withContext(Dispatchers.IO) { client().getMeetingStatus(meetingId) }
            }.onSuccess { status ->
                setStatus(formatMeetingStatus(status))
            }.onFailure { error ->
                setStatus("처리 상태 조회 실패: ${error.message}")
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
        if (projects.isEmpty()) return null
        val index = projectSpinner.selectedItemPosition.takeIf { it in projects.indices } ?: 0
        return projects[index]
    }

    private fun setBusy(busy: Boolean) {
        isBusy = busy
        listOf(
            loginButton,
            logoutButton,
            changePasswordButton,
            refreshProjectsButton,
            refreshProjectMembersButton,
            recordButton,
            uploadButton,
            statusCheckButton,
            checkUpdateButton
        ).forEach { it.isEnabled = !busy }
        openUpdateButton.isEnabled = !busy && pendingUpdate?.apk_url?.isNotBlank() == true
        employeeNoInput.isEnabled = !busy && currentUser == null
        platformUrlInput.isEnabled = !busy
        collectionUrlInput.isEnabled = !busy
        updateProjectSummary()
    }

    private fun setStatus(message: String) {
        if (::statusText.isInitialized) {
            statusText.text = message
        }
    }

    private fun formatMeetingStatus(status: MeetingStatusDto): String =
        listOf(
            "회의 처리 상태: ${status.status} (${status.progress}%)",
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

    private fun updateProjectSummary() {
        if (!::projectSummaryText.isInitialized) return
        val project = selectedProjectOrNull()
        projectSummaryText.text = if (project == null) {
            "프로젝트 없음"
        } else {
            "${project.name}\n${project.project_id}"
        }
        if (::toolbarUser.isInitialized) {
            toolbarUser.text = currentUser?.let { "${it.name} · ${it.role}" } ?: "로그인 필요"
        }
    }

    private fun input(hint: String, value: String): EditText =
        EditText(this).apply {
            this.hint = hint
            setText(value)
            textSize = 15f
            setSingleLine(true)
            setTextColor(color("#17212B"))
            setHintTextColor(color("#8A98A8"))
            setPadding(dp(12), 0, dp(12), 0)
            background = roundedStroke(Color.WHITE, color("#D7E0EA"), dp(10), 1)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)).apply {
                setMargins(0, 0, 0, dp(10))
            }
        }

    private fun passwordInput(hint: String): EditText =
        input(hint, "").apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }

    private fun button(text: String, onClick: () -> Unit): Button =
        Button(this).apply {
            this.text = text
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setAllCaps(false)
            setTextColor(Color.WHITE)
            background = rounded(color("#063D87"), dp(10))
            minHeight = dp(46)
            setOnClickListener { onClick() }
            layoutParams = blockParams(dp(10))
        }

    private fun renderProjectMembers(
        members: List<ProjectMemberDto>,
        emptyMessage: String = "프로젝트 구성원이 없습니다."
    ) {
        projectMemberContainer.removeAllViews()
        if (members.isEmpty()) {
            projectMemberContainer.addView(infoBox(emptyMessage))
            return
        }
        members.forEach { member ->
            projectMemberContainer.addView(
                TextView(this).apply {
                    val emailLabel = member.email ?: "이메일 미등록 · ${member.employee_no}"
                    text = "${member.name} · ${member.project_role} · $emailLabel"
                    textSize = 14f
                    setTextColor(color("#25394C"))
                    setPadding(dp(10), dp(8), dp(10), dp(8))
                    background = roundedStroke(Color.WHITE, color("#D7E0EA"), dp(10), 1)
                    layoutParams = blockParams(dp(8))
                }
            )
        }
    }

    private fun sectionCard(title: String, subtitle: String, vararg children: View): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedStroke(Color.WHITE, color("#D7E0EA"), dp(12), 1)
            val padding = if (isTabletLayout()) dp(18) else dp(16)
            setPadding(padding, dp(16), padding, dp(14))
            layoutParams = blockParams(dp(12))
            addView(
                TextView(this@MainActivity).apply {
                    text = title
                    textSize = 18f
                    typeface = Typeface.DEFAULT_BOLD
                    setTextColor(color("#06306B"))
                }
            )
            if (subtitle.isBlank()) {
                addView(View(this@MainActivity).apply {
                    layoutParams = LinearLayout.LayoutParams(1, dp(10))
                })
            } else {
                addView(
                    TextView(this@MainActivity).apply {
                        text = subtitle
                        textSize = 12f
                        setTextColor(color("#667789"))
                        setPadding(0, dp(4), 0, dp(12))
                    }
                )
            }
            children.forEach { attachChild(it) }
        }

    private fun screenScroll(vararg children: View): ScrollView =
        ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(color("#F4F7FA"))
            addView(
                LinearLayout(this@MainActivity).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(dp(16), dp(16), dp(16), dp(20))
                    children.forEach { attachChild(it) }
                }
            )
        }

    private fun infoBox(text: String): TextView =
        TextView(this).apply {
            this.text = text
            textSize = 14f
            setLineSpacing(4f, 1.0f)
            setTextColor(color("#25394C"))
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = roundedStroke(color("#F8FBFF"), color("#D7E0EA"), dp(10), 1)
            layoutParams = blockParams(dp(10))
        }

    private fun recordingMeter(state: String, time: String, hint: String): TextView =
        TextView(this).apply {
            text = formatRecordingMeterText(state, time, hint)
            textSize = 20f
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setLineSpacing(5f, 1.0f)
            setTextColor(color("#06306B"))
            setPadding(dp(14), dp(24), dp(14), dp(24))
            background = roundedStroke(color("#F9FCFF"), color("#BFD7F4"), dp(12), 1)
            layoutParams = blockParams(dp(10))
        }

    private fun setRecordingMeter(state: String, time: String, hint: String) {
        if (::recordingStateText.isInitialized) {
            recordingStateText.text = formatRecordingMeterText(state, time, hint)
        }
    }

    private fun formatRecordingMeterText(state: String, time: String, hint: String): String {
        val waveform = "▁▃▆▇▅▂▁▂▅▇▆▃▁▃▆▇▅▂▁"
        return listOf(state, time, waveform, hint).filter { it.isNotBlank() }.joinToString("\n")
    }

    private fun actionRow(vararg buttons: Button): LinearLayout =
        LinearLayout(this).apply {
            val horizontal = isTabletLayout()
            orientation = if (horizontal) LinearLayout.HORIZONTAL else LinearLayout.VERTICAL
            buttons.forEachIndexed { index, button ->
                button.layoutParams = if (horizontal) {
                    LinearLayout.LayoutParams(0, dp(48), 1f).apply {
                        setMargins(if (index == 0) 0 else dp(8), 0, 0, dp(10))
                    }
                } else {
                    blockParams(dp(10))
                }
                attachChild(button)
            }
        }

    private fun ViewGroup.attachChild(child: View) {
        (child.parent as? ViewGroup)?.removeView(child)
        addView(child)
    }

    private fun styleButton(target: Button, primary: Boolean) {
        target.setTextColor(Color.WHITE)
        target.background = rounded(if (primary) color("#063D87") else color("#E33242"), dp(10))
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

    private fun color(hex: String): Int = Color.parseColor(hex)

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun isTabletLayout(): Boolean = resources.configuration.screenWidthDp >= 600

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    private fun canUsePlatformApis(): Boolean {
        if (accessToken.isNullOrBlank() || currentUser == null) {
            toast("먼저 로그인하세요.")
            return false
        }
        if (passwordChangeRequired) {
            toast("비밀번호 변경을 먼저 진행하세요.")
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
        requestedByInput.setText("system")
        projectSpinner.adapter = null
        renderProjectMembers(emptyList(), "")
        applyAuthVisibility()
    }

    private fun applyAuthVisibility() {
        val loggedIn = currentUser != null
        loginButton.visibility = if (loggedIn) View.GONE else View.VISIBLE
        logoutButton.visibility = if (loggedIn) View.VISIBLE else View.GONE
        employeeNoInput.visibility = if (loggedIn) View.GONE else View.VISIBLE
        passwordInput.visibility = if (!loggedIn || passwordChangeRequired) View.VISIBLE else View.GONE
        newPasswordInput.visibility = if (passwordChangeRequired) View.VISIBLE else View.GONE
        confirmPasswordInput.visibility = if (passwordChangeRequired) View.VISIBLE else View.GONE
        changePasswordButton.visibility = if (passwordChangeRequired) View.VISIBLE else View.GONE
        checkUpdateButton.visibility = View.GONE
        openUpdateButton.visibility = View.GONE
        setBusy(isBusy)
    }

    companion object {
        private const val REQUEST_RECORD_AUDIO = 1001
        private const val AUTH_PREFS = "ai_pms_auth"
        private const val AUTH_TOKEN_KEY = "access_token"
        private val UPDATE_JSON = Json { ignoreUnknownKeys = true }
    }
}
