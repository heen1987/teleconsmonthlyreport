# MVP Backlog

## Phase 0: Source Alignment

- Confirm product definition as AI-PMS, not standalone meeting minutes service
- Lock boundaries: external App/Web API, internal AI-PMS Backend modules,
  Local LLM AI Analysis Worker, Android, React Web
- Lock `Project_ID` as the linking key for meetings, tasks, schedules,
  resources, risks, costs, and knowledge
- Trace requirements to screens, API contracts, data tables, and tests

## Phase 1: PMS Core And Auth

- Create employee-number login and password change flow
- Add account states: password_change_required, active, locked, disabled
- Create project core, members, member aliases, roles, and permissions
- Create project detail API for schedules, tasks, resources, risks, decisions,
  and meeting history
- Add audit log baseline

## Phase 2: Backend Upload/Collection Module

- Implement upload/collection responsibilities inside AI-PMS Backend
- Create upload session and short-lived upload token
- Receive Android audio upload
- Validate file size, checksum, codec, duration, sample rate, and metadata
- Create analysis job after validation
- Add worker registry, heartbeat, claim, lease, retry, and failure handling
- Update upload/job status through internal state tables or events

## Phase 3: Mac Mini Analysis Worker

- Claim analysis job from AI-PMS Backend job table/API
- Run Whisper.cpp STT
- Structure transcript segments without speaker identity inference
- Call Ollama model with project context snapshot
- Produce JSON with transcript, summary, decisions, action_items, risks, and
  required_resources
- Validate JSON schema before submitting result
- Submit completion/failure status with retry-safe idempotency key

## Phase 4: Backend Meeting And PMS Workflow

- Create meeting under `Project_ID`
- Store the selected `Project_ID`, project context snapshot, and analysis
  result without requiring attendee selection
- Receive analysis result through internal job completion path or Worker completion API
- Store transcript, analysis result, findings, and minutes draft
- Support minutes versioning
- Support review, edit, approve, reject, and supersede
- Convert approved action items to PMS task candidates
- Store decisions, risks, resource candidates, and audit logs

## Phase 5: React Web And Android Screens

- Android A-001 project selection
- Android A-002 project-member auto distribution target confirmation
- Android A-003 recording/upload
- Android A-004 upload/analysis status
- Web W-000 login
- Web W-001 project management
- Web W-002 project members
- Web W-003 meeting list
- Web W-004 minutes review/edit
- Web W-005 approval
- Web W-006 email distribution
- Web W-007 user administration
- Web W-008 password change
- Web W-009 password reset request

## Phase 6: Distribution And Governance

- Generate email preview only after approval
- Send approved minutes to project-member recipients automatically
- Track delivery attempts, retries, partial failure, and final failure
- Add audit logs for review, approval, distribution, and permission changes
- Keep all LLM output as draft/candidate until human approval

## Phase 7: AI-PMS Expansion

- Link due dates from action items into schedule/project detail
- Add resource demand, assignment, reservation, usage, and time sheet loop
- Add task delay and cost overrun risk candidates
- Add document/knowledge indexing
- Add dashboard KPIs: pending reviews, overdue tasks, unresolved risks,
  resource conflicts, distribution failures
- Add ERP/HCM/groupware mappings without replacing their ledgers
