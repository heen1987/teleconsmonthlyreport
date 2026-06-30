from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.routers import (
    admin_users,
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_origin_regex=r"^(http://(localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+|192\.168\.\d+\.\d+)(:\d+)?|https://[a-z0-9-]+\.trycloudflare\.com)$",
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
