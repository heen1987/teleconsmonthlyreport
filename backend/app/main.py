from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.core.config import settings
from app.core.limiter import limiter
from app.routers import (
    admin_users,
    company,
    approvals,
    collection_callbacks,
    dashboard,
    distributions,
    integrations,
    meetings,
    mobile_updates,
    operations,
    projects,
    resources,
    tasks,
    users,
)

app = FastAPI(title=settings.app_name)

# Rate limiting — 브루트포스 방어 (인메모리, 단일 인스턴스)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.platform_cors_allow_origin_list,
    allow_origin_regex=settings.platform_cors_allow_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(projects.router)
app.include_router(meetings.router)
app.include_router(distributions.router)
app.include_router(distributions.ops_router)
app.include_router(approvals.router)
app.include_router(admin_users.router)
app.include_router(company.router)
app.include_router(collection_callbacks.router)
app.include_router(integrations.router)
app.include_router(mobile_updates.router)
app.include_router(users.router)
app.include_router(tasks.router)
app.include_router(resources.router)
app.include_router(dashboard.router)
app.include_router(operations.router)


@app.get("/health")
def health():
    return {"status": "ok", "app": settings.app_name}
