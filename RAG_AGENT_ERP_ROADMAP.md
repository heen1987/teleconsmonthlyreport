# RAG 기반 AI Agent ERP — 확장 로드맵

> **현재 PoC**(로컬 LLM 기반 AI-PMS 회의정보 지능화)에서
> **풀스택 RAG Agent ERP**로 단계적으로 진화하기 위한 아키텍처 문서.

---

## 1. 현재 PoC → 목표 시스템 갭 분석

| 영역 | 현재 PoC | 목표 ERP |
|---|---|---|
| 지식 저장 | LLM 분석 결과를 DB에 저장 | pgvector 기반 벡터 인덱스 + 구조화 KB |
| 쿼리 방식 | REST API 직접 조회 | 자연어 → RAG → 구조화 응답 |
| 에이전트 | 단일 분석 Worker | 멀티 도메인 Agent (업무·자원·리스크·비용) |
| 워크플로우 | 회의록 승인 파이프라인 | 크로스 도메인 자동화 워크플로우 |
| 인터페이스 | React Web + Android | 대화형 AI 인터페이스 + 기존 UI |
| 모델 | Ollama Qwen3 4B (단일) | 멀티모달 LLM Pool + 특화 모델 라우팅 |
| 거버넌스 | 수동 승인 | Human-in-the-loop + 자동 승인 정책 |

---

## 2. 목표 아키텍처

```
┌──────────────────────────────────────────────────────────┐
│                   AI Agent ERP Layer                      │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ Task Agent  │  │Risk Agent   │  │Resource Agent   │  │
│  │ (업무 관리) │  │(리스크 감지)│  │(자원 배정 최적) │  │
│  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘  │
│         │                │                   │           │
│  ┌──────▼────────────────▼───────────────────▼────────┐  │
│  │              Orchestrator Agent                     │  │
│  │   (LangGraph / CrewAI 기반 멀티에이전트 조율)       │  │
│  └──────────────────────┬──────────────────────────────┘  │
│                         │                                  │
│  ┌──────────────────────▼──────────────────────────────┐  │
│  │                  RAG Engine                          │  │
│  │  Query → Embed → Retrieve → Rerank → Generate       │  │
│  └──────────┬──────────────────────────┬───────────────┘  │
│             │                          │                   │
│  ┌──────────▼───────┐     ┌────────────▼──────────────┐   │
│  │  Vector Store    │     │  Structured Knowledge DB  │   │
│  │  (pgvector)      │     │  (PostgreSQL — 현행 유지) │   │
│  │  - 회의록 청크   │     │  - tasks, risks,          │   │
│  │  - 결정 임베딩   │     │    resources, projects    │   │
│  │  - 지식 아이템   │     │    knowledge_items        │   │
│  └──────────────────┘     └───────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
          ▲                              ▲
          │                              │
┌─────────┴───────────┐    ┌─────────────┴────────────────┐
│ Ingestion Pipeline  │    │  Platform API (현행 유지)     │
│ (현행 Analysis       │    │  FastAPI + psycopg3           │
│  Worker 확장)        │    │  Port 8000                   │
│ STT → Chunk → Embed │    └──────────────────────────────┘
│ → pgvector INSERT   │
└─────────────────────┘
```

---

## 3. 단계별 빌드 계획

### Phase 1 — RAG 기반 지식 검색 (2~3개월)

**목표:** 현행 LLM 분석 결과를 벡터화하여 자연어 검색 가능하게 한다.

**작업 목록:**

1. **Embedding Pipeline 추가** (`analysis_server/` 확장)
   - 분석 완료 시 `knowledge_items`, 결정, 액션아이템 청크를 임베딩
   - 모델: `nomic-embed-text` (Ollama) 또는 `bge-m3` (한국어 우수)
   - 저장: `knowledge_embeddings` 테이블 (pgvector `vector(768)`)

   ```sql
   -- 신규 마이그레이션: backend/migrations/NNNN_knowledge_embeddings.sql
   CREATE TABLE IF NOT EXISTS knowledge_embeddings (
       embedding_id    TEXT PRIMARY KEY DEFAULT 'EMB-' || gen_random_uuid()::text,
       project_id      TEXT REFERENCES projects(project_id),
       source_type     TEXT NOT NULL,  -- 'knowledge_item' | 'decision' | 'action_item' | 'meeting_summary'
       source_id       TEXT NOT NULL,
       chunk_index     INT  NOT NULL DEFAULT 0,
       chunk_text      TEXT NOT NULL,
       embedding       vector(768),
       metadata        JSONB DEFAULT '{}',
       created_at      TIMESTAMPTZ DEFAULT now()
   );
   CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_vec
       ON knowledge_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
   CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_project
       ON knowledge_embeddings (project_id, source_type);
   ```

2. **RAG Router 추가** (`backend/app/routers/rag.py`)
   - `POST /rag/query` — 자연어 질의 → 벡터 검색 → LLM 재생성
   - `POST /rag/hybrid-query` — 벡터 + BM25 하이브리드 검색 (pgvector + tsvector)

3. **Chunking 전략**
   - 회의 요약: 전체 1청크
   - 결정/액션아이템: 아이템당 1청크
   - 긴 텍스트: 512 토큰 슬라이딩 윈도우 (128 토큰 오버랩)

---

### Phase 2 — Domain Agent 구현 (3~4개월)

**목표:** 도메인별 전문 Agent가 RAG 컨텍스트를 활용해 PMS 액션을 제안·실행한다.

**Agent 구성:**

```
TaskAgent
  - 역할: 업무 생성·재배정·마감일 협상
  - 트리거: 회의록 승인, 업무 지연 감지
  - 도구: tasks CRUD API, resource availability API
  - 출력: TaskDraft (반드시 사람 승인 후 DB 반영)

RiskAgent
  - 역할: 리스크 선제 감지, 완화 방안 제안
  - 트리거: 업무 지연 > 3일, 자원 충돌, 연속 회의 취소
  - 도구: RAG 검색 (과거 유사 리스크 패턴), risks API
  - 출력: RiskDraft + 유사 사례 근거

ResourceAgent
  - 역할: 자원 배정 최적화, 충돌 해소
  - 트리거: 신규 자원 수요, 배정 충돌 감지
  - 도구: resource_pools API, 프로젝트 일정 조회
  - 출력: AllocationProposal (우선순위 정렬)

CostAgent  [Phase 3]
  - 역할: 예산 소진율 모니터링, 이상 지출 탐지
  - 도구: cost_handoffs API, 외부 ERP 연동
```

**프레임워크 선택:**

| 옵션 | 장점 | 단점 |
|---|---|---|
| **LangGraph** | 상태 그래프 기반, 조건 분기 명확, 로컬 실행 용이 | 러닝커브 있음 |
| CrewAI | Agent 역할 정의 직관적 | 상태 관리 복잡도 낮음 |
| 자체 구현 | 현행 FastAPI에 통합 쉬움 | 멀티에이전트 확장 어려움 |

→ **추천: LangGraph + 현행 FastAPI 코루틴** (AsyncClient 기반)

---

### Phase 3 — 멀티모달 + 외부 ERP 연동 (4~6개월)

**목표:** 실제 ERP(SAP, 영림원, etc.)와 양방향 연동, 대화형 인터페이스 완성.

**주요 작업:**

1. **ERP Connector 레이어** (`backend/app/connectors/`)
   - `SAPConnector`, `YounglimwonConnector` — HTTP 어댑터 패턴
   - `cost_handoffs` 테이블을 통한 비동기 큐 방식 유지
   - Outbox 패턴: DB INSERT → 폴링 워커 → ERP API 호출

2. **대화형 인터페이스**
   - React Web에 채팅 패널 추가 (`/chat` 라우트)
   - WebSocket 또는 SSE 기반 스트리밍 응답
   - `POST /rag/chat` — 멀티턴 대화 + 컨텍스트 유지

3. **모델 라우팅**
   - 짧은 쿼리 → Qwen3 4B (빠름)
   - 복잡한 분석 → Qwen3 8B 또는 Qwen3 14B
   - 임베딩 → bge-m3 전용 인스턴스

4. **Android 확장**
   - 음성 질의: 녹음 → STT → RAG → TTS 읽어주기
   - Push 알림: Agent가 감지한 리스크/지연 실시간 알림

---

## 4. 핵심 데이터 모델 확장

```
[현행]                          [확장]
knowledge_items                 knowledge_embeddings  ← 신규
meetings                        meeting_summaries_vec ← 신규 (벡터 전용)
tasks, risks, resources         (변경 없음 — 구조화 DB 유지)
audit_logs                      agent_action_logs     ← 신규
                                agent_proposals       ← 신규 (승인 대기 Agent 제안)
```

### `agent_proposals` 테이블

```sql
CREATE TABLE IF NOT EXISTS agent_proposals (
    proposal_id     TEXT PRIMARY KEY DEFAULT 'PROP-' || gen_random_uuid()::text,
    project_id      TEXT REFERENCES projects(project_id),
    agent_type      TEXT NOT NULL,        -- 'task' | 'risk' | 'resource' | 'cost'
    action_type     TEXT NOT NULL,        -- 'create_task' | 'promote_risk' | 'reallocate_resource'
    payload         JSONB NOT NULL,       -- Agent가 제안하는 변경 내용
    rationale       TEXT,                 -- RAG 근거 + 분석 이유
    evidence_refs   JSONB DEFAULT '[]',   -- 참조한 knowledge_embeddings IDs
    status          TEXT NOT NULL DEFAULT 'pending',  -- pending|approved|rejected|auto_applied
    reviewed_by     TEXT REFERENCES users(user_id),
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

---

## 5. RAG 파이프라인 설계

```
자연어 질의
    │
    ▼
[1] Query Preprocessing
    - 한국어 전처리 (오타 보정, 동의어 확장)
    - 프로젝트 컨텍스트 필터 추출 (project_id, date range)

    │
    ▼
[2] Hybrid Retrieval
    ├── Dense: pgvector cosine similarity (vector 컬럼)
    └── Sparse: PostgreSQL tsvector FTS (한국어 형태소 — pg_bigm 또는 pgroonga)
    → RRF (Reciprocal Rank Fusion)으로 통합 순위 산출

    │
    ▼
[3] Reranking (선택)
    - cross-encoder 모델로 top-20 → top-5 재정렬
    - Ollama bge-reranker 또는 Qwen3 직접 사용

    │
    ▼
[4] Generation
    - 시스템 프롬프트: 현행 SYSTEM_PROMPT + 검색 컨텍스트 주입
    - /no_think + think: False (현행 유지)
    - 응답 형식: JSON (구조화 응답) 또는 Markdown (채팅 응답)

    │
    ▼
[5] Citation
    - 응답에 참조한 `embedding_id`, `source_id` 명시
    - 프론트엔드에서 원본 회의록 하이라이트 연결
```

---

## 6. Human-in-the-Loop 거버넌스

현행 원칙("LLM 결과는 항상 후보·초안")을 ERP 전체로 확장:

```
Agent 제안
    │
    ├─ 위험도 낮음 + 신뢰도 > 0.9 → 자동 적용 (auto_apply_policy 설정 시)
    │                                audit_logs에 'agent_auto_applied' 기록
    │
    ├─ 위험도 중간               → 담당자에게 Slack/이메일 알림 + 웹 승인 UI
    │
    └─ 위험도 높음 (비용, ERP)   → 관리자 다단계 승인 필수
                                   approvals 테이블 재활용
```

**자동 적용 정책 예시:**
- 지연 3일 이하 태스크 → 마감일 자동 연장 제안 (승인 필요)
- 자원 가용률 > 80% → 배정 최적화 제안 (승인 필요)
- ERP 전표 생성 → 항상 수동 승인 (자동 불가)

---

## 7. 기술 스택 추가 항목

| 레이어 | 현재 | 추가 |
|---|---|---|
| Vector DB | pgvector (설치됨) | `ivfflat` 인덱스 튜닝 |
| Embedding | — | `bge-m3` via Ollama |
| FTS | — | `pg_bigm` (한국어 n-gram) |
| Agent 프레임워크 | — | **LangGraph** (`langgraph>=0.2`) |
| 스트리밍 | — | FastAPI SSE (`sse-starlette`) |
| 모니터링 | 로그 print | **LangSmith** 또는 자체 trace 테이블 |
| 비동기 큐 | 폴링 (현행) | Redis + ARQ (고부하 시) |

---

## 8. 보안 / 멀티테넌시 확장

현행 `project_id` 중심 연결을 RAG 레이어까지 관통시킨다.

- 벡터 검색 시 `WHERE project_id = %s` 필터 **항상** 적용 (테넌트 격리)
- Agent 제안의 `actor_user_id` → Agent 서비스 계정 (`system:agent-{type}`)으로 구분
- `agent_proposals.reviewed_by` → 반드시 사람 user_id (Agent 자신 승인 불가)
- 임베딩 인덱스 접근은 `require_active_user` 미들웨어 통과 후에만 허용

---

## 9. 마이그레이션 경로 (파일 기준)

```
현행 파일                      Phase 1 추가                    Phase 2 추가
─────────────────────────────────────────────────────────────────────────
analysis_server/
  services/llm.py            ← embed.py (임베딩 서비스)
  worker.py                  ← embed_worker.py (임베딩 Worker)

backend/app/
  routers/                   ← rag.py (RAG 검색 API)
                             ← agents.py (Agent 제안 CRUD)
  services/                  ← rag_engine.py (검색 + 생성)
                             ← agents/
                                  task_agent.py
                                  risk_agent.py
                                  resource_agent.py
  migrations/                ← NNNN_knowledge_embeddings.sql
                             ← NNNN_agent_proposals.sql

web_client/src/
  api/client.ts              ← ragApi, agentsApi 추가
  types/index.ts             ← AgentProposal, RAGQueryResult 추가
                             ← pages/ChatPage.tsx (채팅 UI)
```

---

## 10. 체크리스트 — Phase 1 시작 전 완료 조건

- [ ] pgvector extension 설치 확인: `SELECT extname FROM pg_extension WHERE extname = 'vector';`
- [ ] Ollama에 `bge-m3` 또는 `nomic-embed-text` 모델 pull: `ollama pull bge-m3`
- [ ] 현행 `knowledge_items` 테이블에 데이터 누적 확인 (RAG 품질 확보)
- [ ] `NNNN_knowledge_embeddings.sql` 마이그레이션 작성·적용
- [ ] `embed.py` 서비스 작성 및 `analysis_server` 통합
- [ ] `POST /rag/query` 엔드포인트 스모크 테스트 통과

---

> **원칙 재확인:** RAG Agent ERP 전환 이후에도
> "LLM 결과는 항상 후보·초안, 사람 승인 없이 PMS 공식 데이터로 자동 반영하지 않는다"
> 원칙은 유지된다. `agent_proposals` 테이블이 이 게이트 역할을 한다.
