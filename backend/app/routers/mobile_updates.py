from fastapi import APIRouter

from app.core.config import settings
from app.schemas import AndroidUpdateManifestOut

router = APIRouter(prefix="/mobile/android", tags=["mobile-updates"])


@router.get("/update.json", response_model=AndroidUpdateManifestOut)
def android_update_manifest():
    return AndroidUpdateManifestOut(
        enabled=settings.android_update_enabled,
        package_name=settings.android_update_package_name,
        latest_version_code=settings.android_update_latest_version_code,
        latest_version_name=settings.android_update_latest_version_name,
        apk_url=settings.android_update_apk_url or None,
        sha256=settings.android_update_sha256 or None,
        mandatory=settings.android_update_mandatory,
        release_notes=settings.android_update_release_notes,
    )
