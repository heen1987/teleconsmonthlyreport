package com.aipms

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.automirrored.outlined.List
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import com.aipms.client.*

// ─── Design Tokens ────────────────────────────────────────────────────────────
// 웹 styles.css :root 와 동일한 팔레트로 통일
object AppColors {
    val Ink         = Color(0xFF1E293B) // slate 800
    val Muted       = Color(0xFF64748B) // slate 500
    val Line        = Color(0xFFE2E8F0) // slate 200
    val Surface     = Color(0xFFFFFFFF)
    val Background  = Color(0xFFF8FAFC) // slate 50
    val Neutral100  = Color(0xFFF1F5F9) // slate 100

    // Brand - ClovaNote Green Style
    val NavyDeep    = Color(0xFF0F172A) // slate 900
    val SidebarBg   = Color(0xFF0F172A)
    val Accent      = Color(0xFF03C75A) // ClovaNote green
    val AccentSoft  = Color(0xFFEBF9EF) // Soft mint green
    val AccentMid   = Color(0xFFA3E635)
    val Green       = Color(0xFF03C75A)
    val GreenSoft   = Color(0xFFEBF9EF)
    val Warning     = Color(0xFFF59E0B)
    val WarningSoft = Color(0xFFFFFBEB)
    val Danger      = Color(0xFFEF4444)
    val DangerSoft  = Color(0xFFFEF2F2)
    val Cyan        = Color(0xFF06B6D4)
    val Violet      = Color(0xFF7C3AED)
    val VioletSoft  = Color(0xFFF3E8FF)
}

// ─── Theme ────────────────────────────────────────────────────────────────────
@Composable
fun MainAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary          = AppColors.Accent,
            onPrimary        = Color.White,
            secondary        = AppColors.Cyan,
            onSecondary      = Color.White,
            background       = AppColors.Background,
            surface          = AppColors.Surface,
            onBackground     = AppColors.Ink,
            onSurface        = AppColors.Ink,
            surfaceVariant   = AppColors.Neutral100,
            outline          = AppColors.Line,
        ),
        content = content
    )
}

// ─── Navigation ───────────────────────────────────────────────────────────────
enum class MainTab(
    val label: String,
    val activeIcon: ImageVector,
    val inactiveIcon: ImageVector
) {
    HOME("홈", Icons.Filled.Home, Icons.Outlined.Home),
    MEETINGS("회의", Icons.AutoMirrored.Filled.List, Icons.AutoMirrored.Outlined.List),
    PROFILE("프로필", Icons.Filled.Person, Icons.Outlined.Person)
}

// ─── Root App ─────────────────────────────────────────────────────────────────
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AiPmsApp(
    userName: String = "사용자",
    projects: List<ProjectDto> = emptyList(),
    selectedProjectId: String? = null,
    projectMembers: List<ProjectMemberDto> = emptyList(),
    companyContext: CompanyContextDto? = null,
    statusMessage: String = "",
    activeMeetingId: String? = null,
    latestMeetingStatus: MeetingStatusDto? = null,
    uploadedSegmentCount: Int = 0,
    recordingState: String = "녹음 대기",
    recordingTime: String = "--",
    recordingHint: String = "",
    isRecording: Boolean = false,
    isBusy: Boolean = false,
    onLogout: () -> Unit = {},
    onProjectSelected: (String) -> Unit = {},
    onRefreshProjects: () -> Unit = {},
    onRefreshStatus: () -> Unit = {},
    onRecordClick: () -> Unit = {}
) {
    var selectedTab by remember { mutableStateOf(MainTab.HOME) }

    Scaffold(
        topBar = { MeetflowTopBar(userName = userName) },
        bottomBar = {
            MeetflowBottomBar(
                selectedTab = selectedTab,
                onTabSelect = { selectedTab = it }
            )
        },
        floatingActionButton = {
            RecordFab(isRecording = isRecording, onClick = onRecordClick)
        },
        floatingActionButtonPosition = FabPosition.Center,
        containerColor = AppColors.Background
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .padding(paddingValues)
                .fillMaxSize()
        ) {
            when (selectedTab) {
                MainTab.HOME     -> HomeScreen(
                    userName = userName,
                    projects = projects,
                    selectedProjectId = selectedProjectId,
                    projectMembers = projectMembers,
                    companyContext = companyContext,
                    statusMessage = statusMessage,
                    activeMeetingId = activeMeetingId,
                    latestMeetingStatus = latestMeetingStatus,
                    uploadedSegmentCount = uploadedSegmentCount,
                    recordingState = recordingState,
                    recordingTime = recordingTime,
                    recordingHint = recordingHint,
                    isRecording = isRecording,
                    isBusy = isBusy,
                    onNavigate = { selectedTab = it },
                    onProjectSelected = onProjectSelected,
                    onRefreshProjects = onRefreshProjects,
                    onRefreshStatus = onRefreshStatus,
                    onRecordClick = onRecordClick
                )
                MainTab.MEETINGS -> MeetingsScreen(
                    projects = projects,
                    selectedProjectId = selectedProjectId,
                    activeMeetingId = activeMeetingId,
                    latestMeetingStatus = latestMeetingStatus,
                    onProjectSelected = onProjectSelected,
                    onRefreshProjects = onRefreshProjects,
                    onRefreshStatus = onRefreshStatus
                )
                MainTab.PROFILE  -> ProfileScreen(userName = userName, onLogout = onLogout)
            }
        }
    }
}

// ─── TopBar ───────────────────────────────────────────────────────────────────
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeetflowTopBar(userName: String) {
    TopAppBar(
        title = {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                // Brand mark
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(RoundedCornerShape(9.dp))
                        .background(
                            Brush.linearGradient(listOf(AppColors.Cyan, AppColors.Accent))
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text("M", color = Color.White, fontWeight = FontWeight.Black, fontSize = 18.sp)
                }
                Column {
                    Text("MEETFLOW", fontWeight = FontWeight.Black, fontSize = 17.sp, color = AppColors.Ink, letterSpacing = 0.5.sp)
                    Text("AI-PMS Recorder", fontSize = 11.sp, color = AppColors.Muted)
                }
            }
        },
        actions = {
            // Avatar chip
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = AppColors.AccentSoft,
                modifier = Modifier.padding(end = 14.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .clip(CircleShape)
                            .background(AppColors.Accent),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            userName.take(1),
                            color = Color.White,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Text(userName, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Accent)
                }
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = AppColors.Surface,
            titleContentColor = AppColors.Ink
        )
    )
}

// ─── BottomBar ────────────────────────────────────────────────────────────────
@Composable
fun MeetflowBottomBar(selectedTab: MainTab, onTabSelect: (MainTab) -> Unit) {
    Surface(
        color = AppColors.Surface,
        shadowElevation = 8.dp,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            MainTab.entries.forEach { tab ->
                val isSelected = selectedTab == tab
                val isCenterGap = tab == MainTab.MEETINGS
                // Center tab leaves space for FAB
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .then(if (isCenterGap) Modifier else Modifier),
                    contentAlignment = Alignment.Center
                ) {
                    if (!isCenterGap) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .clickable { onTabSelect(tab) }
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Icon(
                                if (isSelected) tab.activeIcon else tab.inactiveIcon,
                                contentDescription = tab.label,
                                tint = if (isSelected) AppColors.Accent else AppColors.Muted,
                                modifier = Modifier.size(22.dp)
                            )
                            Spacer(Modifier.height(2.dp))
                            Text(
                                tab.label,
                                fontSize = 11.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) AppColors.Accent else AppColors.Muted
                            )
                        }
                    } else {
                        // Gap for center FAB
                        Spacer(Modifier.size(64.dp))
                    }
                }
            }
        }
    }
}

// ─── Record FAB ───────────────────────────────────────────────────────────────
@Composable
fun RecordFab(isRecording: Boolean, onClick: () -> Unit) {
    val fabColor by animateColorAsState(
        targetValue = if (isRecording) AppColors.Danger else AppColors.Accent,
        animationSpec = tween(300),
        label = "fabColor"
    )
    val fabScale by animateFloatAsState(
        targetValue = if (isRecording) 1.12f else 1f,
        animationSpec = tween(300),
        label = "fabScale"
    )

    FloatingActionButton(
        onClick = onClick,
        containerColor = fabColor,
        contentColor = Color.White,
        shape = CircleShape,
        elevation = FloatingActionButtonDefaults.elevation(defaultElevation = 6.dp),
        modifier = Modifier
            .size(62.dp)
            .scale(fabScale)
            .offset(y = (-4).dp)
    ) {
        Icon(
            if (isRecording) Icons.Filled.Close else Icons.Filled.PlayArrow,
            contentDescription = if (isRecording) "녹음 중지" else "녹음 시작",
            modifier = Modifier.size(28.dp)
        )
    }
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────
@Composable
fun HomeScreen(
    userName: String,
    projects: List<ProjectDto>,
    selectedProjectId: String?,
    projectMembers: List<ProjectMemberDto>,
    companyContext: CompanyContextDto?,
    statusMessage: String,
    activeMeetingId: String?,
    latestMeetingStatus: MeetingStatusDto?,
    uploadedSegmentCount: Int,
    recordingState: String,
    recordingTime: String,
    recordingHint: String,
    isRecording: Boolean,
    isBusy: Boolean,
    onNavigate: (MainTab) -> Unit,
    onProjectSelected: (String) -> Unit,
    onRefreshProjects: () -> Unit,
    onRefreshStatus: () -> Unit,
    onRecordClick: () -> Unit
) {
    val selectedProject = projects.firstOrNull { it.project_id == selectedProjectId }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            HomeHero(userName = userName)
        }

        item {
            ProjectSetupCard(
                projects = projects,
                selectedProjectId = selectedProjectId,
                projectMembers = projectMembers,
                companyContext = companyContext,
                onProjectSelected = onProjectSelected,
                onRefreshProjects = onRefreshProjects
            )
        }

        item {
            RecordingControlCard(
                selectedProject = selectedProject,
                isRecording = isRecording,
                isBusy = isBusy,
                activeMeetingId = activeMeetingId,
                uploadedSegmentCount = uploadedSegmentCount,
                recordingState = recordingState,
                recordingTime = recordingTime,
                recordingHint = recordingHint,
                onRecordClick = onRecordClick
            )
        }

        item {
            PipelineStatusCard(
                statusMessage = statusMessage,
                latestMeetingStatus = latestMeetingStatus,
                activeMeetingId = activeMeetingId,
                onRefreshStatus = onRefreshStatus,
                onOpenMeetings = { onNavigate(MainTab.MEETINGS) }
            )
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                QuickActionCard(
                    icon = Icons.AutoMirrored.Filled.List,
                    label = "회의 상태",
                    color = AppColors.Warning,
                    modifier = Modifier.weight(1f),
                    onClick = { onNavigate(MainTab.MEETINGS) }
                )
                QuickActionCard(
                    icon = Icons.AutoMirrored.Filled.Send,
                    label = "웹 검토",
                    color = AppColors.Green,
                    modifier = Modifier.weight(1f),
                    onClick = { onNavigate(MainTab.MEETINGS) }
                )
            }
        }
    }
}

// ─── HomeHero ─────────────────────────────────────────────────────────────────
@Composable
fun HomeHero(userName: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(
                Brush.linearGradient(
                    listOf(AppColors.NavyDeep, Color(0xFF0F2A48), Color(0xFF0D3F5A))
                )
            )
            .padding(22.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                "${userName}님,\n회의 녹음",
                fontSize = 22.sp,
                fontWeight = FontWeight.Black,
                color = Color.White,
                lineHeight = 30.sp
            )
        }
    }
}

@Composable
fun ProjectSetupCard(
    projects: List<ProjectDto>,
    selectedProjectId: String?,
    projectMembers: List<ProjectMemberDto>,
    companyContext: CompanyContextDto?,
    onProjectSelected: (String) -> Unit,
    onRefreshProjects: () -> Unit
) {
    val selectedProject = projects.firstOrNull { it.project_id == selectedProjectId }
    var expanded by remember { mutableStateOf(false) }
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = AppColors.Surface,
        shape = RoundedCornerShape(14.dp),
        border = ButtonDefaults.outlinedButtonBorder(enabled = true),
        shadowElevation = 1.dp
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("프로젝트 설정", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = AppColors.Ink)
                    Text(
                        companyContext?.profile?.company_name ?: "회사 정보 로딩",
                        fontSize = 12.sp,
                        color = AppColors.Muted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                OutlinedButton(onClick = onRefreshProjects, shape = RoundedCornerShape(10.dp)) {
                    Icon(Icons.Filled.Settings, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("새로고침", fontSize = 12.sp)
                }
            }

            Box {
                OutlinedButton(
                    onClick = { expanded = true },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.AutoMirrored.Filled.List, contentDescription = null, tint = AppColors.Accent)
                    Spacer(Modifier.width(8.dp))
                    Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.Start) {
                        Text(
                            selectedProject?.name ?: "프로젝트 선택",
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.Ink,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            selectedProject?.project_id ?: "${projects.size}개 프로젝트",
                            fontSize = 11.sp,
                            color = AppColors.Muted,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = AppColors.Muted)
                }
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    if (projects.isEmpty()) {
                        DropdownMenuItem(
                            text = { Text("프로젝트 없음") },
                            onClick = { expanded = false }
                        )
                    }
                    projects.forEach { project ->
                        DropdownMenuItem(
                            text = {
                                Column {
                                    Text(project.name, fontWeight = FontWeight.SemiBold)
                                    Text(project.project_id, fontSize = 11.sp, color = AppColors.Muted)
                                }
                            },
                            onClick = {
                                expanded = false
                                onProjectSelected(project.project_id)
                            }
                        )
                    }
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                InfoPill(label = "구성원", value = "${projectMembers.size}명", color = AppColors.Accent)
                InfoPill(label = "프로젝트", value = "${projects.size}건", color = AppColors.Green)
            }
        }
    }
}

@Composable
fun RecordingWaveform() {
    var phase by remember { mutableStateOf(0f) }
    LaunchedEffect(Unit) {
        while(true) {
            kotlinx.coroutines.delay(100)
            phase += 0.4f
        }
    }
    Row(
        modifier = Modifier.fillMaxWidth().height(60.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (i in 0 until 18) {
            val scale = 10 + Math.abs(Math.sin((phase + i * 0.35f).toDouble())) * 40
            Box(
                modifier = Modifier
                    .padding(horizontal = 2.dp)
                    .width(4.dp)
                    .height(scale.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(AppColors.Accent)
            )
        }
    }
}

@Composable
fun RecordingControlCard(
    selectedProject: ProjectDto?,
    isRecording: Boolean,
    isBusy: Boolean,
    activeMeetingId: String?,
    uploadedSegmentCount: Int,
    recordingState: String,
    recordingTime: String,
    recordingHint: String,
    onRecordClick: () -> Unit
) {
    val disabled = selectedProject == null || (!isRecording && isBusy)
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = AppColors.Surface,
        shape = RoundedCornerShape(14.dp),
        border = ButtonDefaults.outlinedButtonBorder(enabled = true),
        shadowElevation = 1.dp
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    modifier = Modifier.size(44.dp).clip(CircleShape).background(
                        if (isRecording) AppColors.DangerSoft else AppColors.AccentSoft
                    ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        if (isRecording) Icons.Filled.Close else Icons.Filled.PlayArrow,
                        contentDescription = null,
                        tint = if (isRecording) AppColors.Danger else AppColors.Accent
                    )
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(recordingState, fontWeight = FontWeight.Bold, fontSize = 16.sp, color = AppColors.Ink)
                    Text(recordingTime, fontSize = 12.sp, color = AppColors.Muted)
                }
                InfoPill(label = "Segment", value = "${uploadedSegmentCount}건", color = AppColors.Warning)
            }

            Text(
                recordingHint.ifBlank { selectedProject?.name ?: "프로젝트 선택 필요" },
                fontSize = 13.sp,
                color = AppColors.Muted
            )

            if (isRecording) {
                Spacer(modifier = Modifier.height(8.dp))
                RecordingWaveform()
                Spacer(modifier = Modifier.height(8.dp))
            }

            if (!activeMeetingId.isNullOrBlank()) {
                Text(
                    activeMeetingId,
                    fontSize = 11.sp,
                    color = AppColors.Muted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Button(
                onClick = onRecordClick,
                enabled = !disabled,
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isRecording) AppColors.Danger else AppColors.Accent
                )
            ) {
                Icon(
                    if (isRecording) Icons.Filled.Close else Icons.Filled.PlayArrow,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(if (isRecording) "녹음 중지" else "녹음 시작", fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun PipelineStatusCard(
    statusMessage: String,
    latestMeetingStatus: MeetingStatusDto?,
    activeMeetingId: String?,
    onRefreshStatus: () -> Unit,
    onOpenMeetings: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = AppColors.Surface,
        shape = RoundedCornerShape(14.dp),
        border = ButtonDefaults.outlinedButtonBorder(enabled = true),
        shadowElevation = 1.dp
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("처리 상태", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = AppColors.Ink)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    IconButton(onClick = onRefreshStatus, enabled = !activeMeetingId.isNullOrBlank()) {
                        Icon(Icons.Filled.Settings, contentDescription = "상태 새로고침", tint = AppColors.Accent)
                    }
                    IconButton(onClick = onOpenMeetings) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = "회의 화면", tint = AppColors.Muted)
                    }
                }
            }
            latestMeetingStatus?.let { status ->
                LinearProgressIndicator(
                    progress = { status.progress / 100f },
                    modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(20.dp)),
                    color = statusTone(status.status),
                    trackColor = AppColors.Neutral100
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    InfoPill(label = "회의", value = status.status, color = statusTone(status.status))
                    InfoPill(label = "분석", value = status.latest_analysis_status ?: "-", color = AppColors.Violet)
                }
            }
            Text(
                statusMessage.ifBlank { "상태 메시지 없음" },
                fontSize = 13.sp,
                color = AppColors.Muted,
                lineHeight = 18.sp
            )
        }
    }
}

@Composable
fun InfoPill(label: String, value: String, color: Color) {
    Surface(color = color.copy(alpha = 0.1f), shape = RoundedCornerShape(20.dp)) {
        Text(
            "$label $value",
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
            color = color,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

fun statusTone(status: String): Color =
    when {
        status.endsWith("_failed") -> AppColors.Danger
        status == "review_required" -> AppColors.Warning
        status == "approved" || status == "distributed" -> AppColors.Green
        else -> AppColors.Accent
    }

// ─── QuickActionCard ──────────────────────────────────────────────────────────
@Composable
fun QuickActionCard(
    icon: ImageVector,
    label: String,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .clickable(onClick = onClick),
        color = AppColors.Surface,
        shape = RoundedCornerShape(14.dp),
        border = ButtonDefaults.outlinedButtonBorder(enabled = true),
        shadowElevation = 2.dp
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(42.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(color.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
            }
            Text(label, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = AppColors.Ink)
        }
    }
}

// ─── MeetingsScreen ───────────────────────────────────────────────────────────
@Composable
fun MeetingsScreen(
    projects: List<ProjectDto>,
    selectedProjectId: String?,
    activeMeetingId: String?,
    latestMeetingStatus: MeetingStatusDto?,
    onProjectSelected: (String) -> Unit,
    onRefreshProjects: () -> Unit,
    onRefreshStatus: () -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            ProjectSetupCard(
                projects = projects,
                selectedProjectId = selectedProjectId,
                projectMembers = emptyList(),
                companyContext = null,
                onProjectSelected = onProjectSelected,
                onRefreshProjects = onRefreshProjects
            )
        }
        item {
            PipelineStatusCard(
                statusMessage = latestMeetingStatus?.let {
                    "회의 ${it.meeting_id} · ${it.status} · ${it.progress}%"
                } ?: "상태 조회 대상 회의가 없습니다.",
                latestMeetingStatus = latestMeetingStatus,
                activeMeetingId = activeMeetingId,
                onRefreshStatus = onRefreshStatus,
                onOpenMeetings = {}
            )
        }
        latestMeetingStatus?.let { status ->
            item {
                MeetingCard(
                    title = status.title,
                    statusLabel = status.status,
                    status = meetingStatusFromServer(status.status)
                )
            }
        }
    }
}

// ─── MeetingCard ──────────────────────────────────────────────────────────────
enum class MeetingStatus { DONE, PENDING, PROCESSING, ERROR }

fun meetingStatusFromServer(status: String): MeetingStatus =
    when {
        status.endsWith("_failed") || status == "review_rejected" -> MeetingStatus.ERROR
        status == "review_required" -> MeetingStatus.PENDING
        status == "approved" || status == "distributed" -> MeetingStatus.DONE
        else -> MeetingStatus.PROCESSING
    }

@Composable
fun MeetingCard(
    title: String,
    statusLabel: String,
    status: MeetingStatus,
    onClick: (() -> Unit)? = null
) {
    val (statusColor, statusBg, statusIcon) = when (status) {
        MeetingStatus.DONE       -> Triple(AppColors.Green, AppColors.GreenSoft, Icons.Filled.CheckCircle)
        MeetingStatus.PENDING    -> Triple(AppColors.Warning, AppColors.WarningSoft, Icons.Filled.Info)
        MeetingStatus.PROCESSING -> Triple(AppColors.Accent, AppColors.AccentSoft, Icons.Filled.Settings)
        MeetingStatus.ERROR      -> Triple(AppColors.Danger, AppColors.DangerSoft, Icons.Filled.Warning)
    }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        color = AppColors.Surface,
        shape = RoundedCornerShape(12.dp),
        shadowElevation = 1.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .border(
                    width = 1.dp,
                    color = AppColors.Line,
                    shape = RoundedCornerShape(12.dp)
                )
                // Status left bar via background trick
                .padding(start = 0.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Colored left accent bar
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(72.dp)
                    .background(statusColor, RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp))
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Icon badge
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(statusBg),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(statusIcon, contentDescription = null, tint = statusColor, modifier = Modifier.size(20.dp))
                }

                // Title + status
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        title,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        color = AppColors.Ink,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Surface(
                        color = statusBg,
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Text(
                            statusLabel,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = statusColor
                        )
                    }
                }

                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = AppColors.Muted,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

// ─── ProfileScreen ────────────────────────────────────────────────────────────
@Composable
fun ProfileScreen(userName: String, onLogout: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Avatar section
        item {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = AppColors.Surface,
                shape = RoundedCornerShape(16.dp),
                shadowElevation = 1.dp
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(80.dp)
                            .clip(CircleShape)
                            .background(
                                Brush.linearGradient(listOf(AppColors.Cyan, AppColors.Accent))
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            userName.take(1),
                            color = Color.White,
                            fontSize = 34.sp,
                            fontWeight = FontWeight.Black
                        )
                    }
                    Text(userName, fontWeight = FontWeight.Bold, fontSize = 20.sp, color = AppColors.Ink)
                    Surface(
                        color = AppColors.AccentSoft,
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Text(
                            "임직원",
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 5.dp),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.Accent
                        )
                    }
                }
            }
        }

        item {
            Button(
                onClick = onLogout,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.DangerSoft,
                    contentColor = AppColors.Danger
                )
            ) {
                Icon(Icons.Filled.Close, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("로그아웃", fontWeight = FontWeight.Bold, fontSize = 15.sp)
            }
        }
    }
}

// ─── PasswordChangeScreen ────────────────────────────────────────────────────
@Composable
fun PasswordChangeScreen(
    userName: String,
    employeeNo: String,
    errorMessage: String = "",
    onChangeClick: (currentPw: String, newPw: String, confirmPw: String) -> Unit
) {
    var currentPw  by remember { mutableStateOf("") }
    var newPw      by remember { mutableStateOf("") }
    var confirmPw  by remember { mutableStateOf("") }
    var currentVisible by remember { mutableStateOf(false) }
    var newVisible     by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(listOf(Color(0xFFF0F4F8), Color(0xFFE8F0FA)))),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(62.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(AppColors.WarningSoft),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Lock, contentDescription = null, tint = AppColors.Warning, modifier = Modifier.size(32.dp))
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("비밀번호 변경 필요", fontWeight = FontWeight.Black, fontSize = 20.sp, color = AppColors.NavyDeep)
                Text("초기 비밀번호를 변경해 주세요.", fontSize = 13.sp, color = AppColors.Muted)
                Text(userName, fontSize = 12.sp, color = AppColors.Accent, fontWeight = FontWeight.Bold)
            }

            Surface(color = AppColors.Surface, shape = RoundedCornerShape(20.dp), shadowElevation = 4.dp, modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {

                    OutlinedTextField(
                        value = currentPw,
                        onValueChange = { currentPw = it },
                        label = { Text("현재 비밀번호") },
                        leadingIcon = { Icon(Icons.Outlined.Lock, null, tint = AppColors.Muted) },
                        trailingIcon = {
                            IconButton(onClick = { currentVisible = !currentVisible }) {
                                Icon(if (currentVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, null, tint = AppColors.Muted)
                            }
                        },
                        visualTransformation = if (currentVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Accent, focusedLabelColor = AppColors.Accent)
                    )

                    OutlinedTextField(
                        value = newPw,
                        onValueChange = { newPw = it },
                        label = { Text("새 비밀번호") },
                        leadingIcon = { Icon(Icons.Outlined.Lock, null, tint = AppColors.Muted) },
                        trailingIcon = {
                            IconButton(onClick = { newVisible = !newVisible }) {
                                Icon(if (newVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, null, tint = AppColors.Muted)
                            }
                        },
                        visualTransformation = if (newVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Accent, focusedLabelColor = AppColors.Accent)
                    )

                    OutlinedTextField(
                        value = confirmPw,
                        onValueChange = { confirmPw = it },
                        label = { Text("새 비밀번호 확인") },
                        leadingIcon = { Icon(Icons.Outlined.Lock, null, tint = AppColors.Muted) },
                        visualTransformation = PasswordVisualTransformation(),
                        isError = confirmPw.isNotBlank() && confirmPw != newPw,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Accent, focusedLabelColor = AppColors.Accent)
                    )

                    if (confirmPw.isNotBlank() && confirmPw != newPw) {
                        Text("새 비밀번호가 일치하지 않습니다.", fontSize = 12.sp, color = AppColors.Danger)
                    }

                    if (errorMessage.isNotBlank()) {
                        Surface(color = AppColors.DangerSoft, shape = RoundedCornerShape(8.dp), modifier = Modifier.fillMaxWidth()) {
                            Row(modifier = Modifier.padding(10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Filled.Warning, null, tint = AppColors.Danger, modifier = Modifier.size(16.dp))
                                Text(errorMessage, fontSize = 12.sp, color = AppColors.Danger)
                            }
                        }
                    }

                    Button(
                        onClick = { onChangeClick(currentPw, newPw, confirmPw) },
                        enabled = currentPw.isNotBlank() && newPw.isNotBlank() && newPw == confirmPw,
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.Accent)
                    ) {
                        Text("비밀번호 변경", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                }
            }
        }
    }
}

// ─── AppLoginScreen ───────────────────────────────────────────────────────────
@Composable
fun AppLoginScreen(
    serverUrl: String = "",
    onServerUrlChange: (String) -> Unit = {},
    errorMessage: String = "",
    onLoginClick: (String, String) -> Unit
) {
    var employeeNo by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    var showServerUrl by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(listOf(Color(0xFFF0F4F8), Color(0xFFE8F0FA)))
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Brand
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.linearGradient(listOf(AppColors.Cyan, AppColors.Accent))),
                contentAlignment = Alignment.Center
            ) {
                Text("M", color = Color.White, fontSize = 38.sp, fontWeight = FontWeight.Black)
            }

            Spacer(Modifier.height(20.dp))

            Text(
                "MEETFLOW",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Black,
                color = AppColors.NavyDeep,
                letterSpacing = 1.sp
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "AI 기반 스마트 프로젝트 관리 시스템",
                fontSize = 13.sp,
                color = AppColors.Muted
            )

            Spacer(Modifier.height(40.dp))

            // Login card
            Surface(
                color = AppColors.Surface,
                shape = RoundedCornerShape(20.dp),
                shadowElevation = 4.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Text(
                        "로그인",
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp,
                        color = AppColors.Ink
                    )

                    // 서버 주소 (접기/펼치기)
                    Surface(
                        color = AppColors.Neutral100,
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { showServerUrl = !showServerUrl }
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Icon(
                                        Icons.Outlined.Settings,
                                        contentDescription = null,
                                        tint = AppColors.Muted,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Text("서버 주소 설정", fontSize = 13.sp, color = AppColors.Muted)
                                }
                                Icon(
                                    if (showServerUrl) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
                                    contentDescription = null,
                                    tint = AppColors.Muted,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                            if (showServerUrl) {
                                OutlinedTextField(
                                    value = serverUrl,
                                    onValueChange = onServerUrlChange,
                                    label = { Text("Platform API URL") },
                                    placeholder = { Text("https://platform.example.com", fontSize = 12.sp) },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 10.dp)
                                        .padding(bottom = 10.dp),
                                    shape = RoundedCornerShape(10.dp),
                                    singleLine = true,
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = AppColors.Accent,
                                        focusedLabelColor = AppColors.Accent
                                    )
                                )
                            }
                        }
                    }

                    OutlinedTextField(
                        value = employeeNo,
                        onValueChange = { employeeNo = it },
                        label = { Text("사번") },
                        leadingIcon = { Icon(Icons.Outlined.Person, contentDescription = null, tint = AppColors.Muted) },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AppColors.Accent,
                            focusedLabelColor = AppColors.Accent
                        )
                    )

                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text("비밀번호") },
                        leadingIcon = { Icon(Icons.Outlined.Lock, contentDescription = null, tint = AppColors.Muted) },
                        trailingIcon = {
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(
                                    if (passwordVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff,
                                    contentDescription = if (passwordVisible) "비밀번호 숨기기" else "비밀번호 보기",
                                    tint = AppColors.Muted
                                )
                            }
                        },
                        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AppColors.Accent,
                            focusedLabelColor = AppColors.Accent
                        )
                    )

                    // 로그인 에러 메시지
                    if (errorMessage.isNotBlank()) {
                        Surface(
                            color = AppColors.DangerSoft,
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(10.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Filled.Warning,
                                    contentDescription = null,
                                    tint = AppColors.Danger,
                                    modifier = Modifier.size(16.dp)
                                )
                                Text(
                                    errorMessage,
                                    fontSize = 12.sp,
                                    color = AppColors.Danger,
                                    lineHeight = 17.sp
                                )
                            }
                        }
                    }

                    Spacer(Modifier.height(4.dp))

                    Button(
                        onClick = { onLoginClick(employeeNo, password) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.Accent),
                        enabled = employeeNo.isNotBlank() && password.isNotBlank()
                    ) {
                        Text("로그인 시작하기", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                }
            }
        }
    }
}

// ─── Previews ────────────────────────────────────────────────────────────────
@Preview(showBackground = true, widthDp = 360, heightDp = 720)
@Composable
fun AiPmsAppPreview() {
    MainAppTheme {
        AiPmsApp(
            userName = "김희섭",
            projects = listOf(
                ProjectDto("PRJ-2026-001", "AI-PMS 로컬 고도화", null, "active"),
                ProjectDto("PRJ-2026-002", "차세대 ERP 연동", null, "active")
            ),
            selectedProjectId = "PRJ-2026-001",
            statusMessage = "분석 서버가 준비되었습니다.",
            recordingState = "녹음 대기",
            recordingTime = "00:00:00",
            recordingHint = "AI-PMS 로컬 고도화 프로젝트 회의를 시작할 수 있습니다."
        )
    }
}

@Preview(showBackground = true, widthDp = 360, heightDp = 720)
@Composable
fun AppLoginScreenPreview() {
    MainAppTheme {
        AppLoginScreen(
            serverUrl = "https://platform.example.com",
            onServerUrlChange = {},
            onLoginClick = { _, _ -> }
        )
    }
}
