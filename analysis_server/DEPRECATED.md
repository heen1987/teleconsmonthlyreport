# analysis_server — 통합 완료

이 파일은 이전 세션에서 잘못 생성된 것입니다. **`analysis_server/` 는 Deprecated 가 아닙니다.**

`analysis_server/` 는 `collection_api/` 를 흡수하여 **단일 통합 서버**가 되었습니다.

- **포트**: `:8200`
- **역할**: 오디오 업로드 수집 + STT/LLM 분석 + Platform API 콜백
- **실행**: `scripts/windows_run_analysis_server.ps1`

Deprecated 된 것은 `collection_api/` 입니다. `collection_api/DEPRECATED.md` 를 참조하세요.
