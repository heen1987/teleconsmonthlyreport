import asyncio

from app.core.config import settings
from app.services.collection_client import claim_job, get_audio_asset, heartbeat, update_job
from app.services.llm import analyze_transcript
from app.services.stt import transcribe_audio_uri


async def run_once() -> None:
    await heartbeat()
    job = await claim_job()
    if not job:
        print("No queued collection job")
        return

    job_id = job["job_id"]
    print(f"Claimed {job_id}")
    try:
        await update_job(job_id, "start", {"message": "worker accepted job"})
        transcript = job.get("transcript_text")
        if not transcript:
            asset_id = job.get("asset_id")
            if not asset_id:
                raise RuntimeError("Collection job has neither transcript_text nor asset_id")
            asset = await get_audio_asset(asset_id)
            storage_uri = asset.get("storage_uri")
            if not storage_uri:
                raise RuntimeError(f"Audio asset {asset_id} has no storage_uri")
            transcript = await transcribe_audio_uri(storage_uri, job.get("language") or "ko")
        result = await analyze_transcript(transcript)
        await update_job(
            job_id,
            "complete",
            {
                "model_name": settings.ollama_model,
                "result": result.model_dump(mode="json"),
            },
        )
        print(f"Completed {job_id}")
    except Exception as exc:
        try:
            await update_job(job_id, "fail", error_message=str(exc))
        except Exception as status_exc:
            print(f"Failed to mark {job_id} as failed after {type(exc).__name__}: {status_exc}")
        raise


if __name__ == "__main__":
    asyncio.run(run_once())
