"""
API Rate Limiter (slowapi)

외부 네트워크에 노출된 엔드포인트의 브루트포스·스팸 방어용.
단일 인스턴스(Mac mini) 기준 인메모리 카운터 사용.
Redis 기반 분산 제한이 필요한 경우 storage_uri 에 Redis URL 설정.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(
    key_func=get_remote_address,
    # storage_uri="redis://localhost:6379",  # 분산 배포 시 주석 해제
)
