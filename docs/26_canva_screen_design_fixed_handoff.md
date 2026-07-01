# Canva Screen Design Fixed Handoff

## Purpose

This document freezes the AI-PMS MEETFLOW app and web screen-design output for
handoff to Canva, presentation review, and implementation alignment.

Canva direct generation was attempted for this screen-design package, but the
Canva connector returned `quota_exceeded`. The fixed local deliverable is
therefore a Canva-import-ready PowerPoint deck generated from the Google Drive
screen-design images.

## Fixed Deliverables

- PPTX:
  `/Users/ppp/Library/CloudStorage/GoogleDrive-heen1987@gmail.com/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1/ai_pms_bootstrap/outputs/AI-PMS_MEETFLOW_screen_design_fixed.pptx`
- Manifest:
  `/Users/ppp/Library/CloudStorage/GoogleDrive-heen1987@gmail.com/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1/ai_pms_bootstrap/outputs/AI-PMS_MEETFLOW_screen_design_fixed_manifest.json`
- Render previews:
  `/Users/ppp/Library/CloudStorage/GoogleDrive-heen1987@gmail.com/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1/ai_pms_bootstrap/outputs/screen_design_fixed_preview`
- Public handoff JSON:
  `/Users/ppp/Library/CloudStorage/GoogleDrive-heen1987@gmail.com/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1/ai_pms_bootstrap/web_client/public/handoff/canva-screen-design-fixed.json`

## Fixed Slide Set

| Slide | Screen ID | Scope |
| --- | --- | --- |
| 01 | COVER | AI-PMS MEETFLOW screen-design fixed output |
| 02 | SCOPE | MVP screen scope lock |
| 03 | APP FLOW | Login, project selection, recording, upload status |
| 04 | APP-01 | Login and home entry |
| 05 | APP-02 | Project selection |
| 06 | APP-04 | Meeting recording |
| 07 | APP-05 | Upload and analysis status |
| 08 | WEB-01 | Project workspace |
| 09 | WEB-02 | Task board and PMS reflection |
| 10 | WEB-03 | Document space and minutes review |
| 11 | ADMIN-01 | Operations admin dashboard |
| 12 | CHECK | Implementation and deliverable linkage |

## Non-Negotiable UI Rules

- PMS remains the main product. Meeting recording and analysis is one module.
- The app is recording-first. It must not become a full PMS mobile app.
- The app flow is: login, project selection, meeting recording, upload/status.
- The user selects only the project for a meeting. Attendee selection is not a
  required step.
- Distribution uses project members automatically. External email recipients
  are optional additions in the web review/distribution flow.
- AI analysis is agenda/content/decision/action/risk/resource/knowledge
  centered. It must not infer speaker, attendee, owner, or responsibility when
  the source does not explicitly provide it.
- The web experience owns review, approval, distribution, PMS reflection, admin
  status, and audit work.
- Use MEETFLOW naming and the navy, teal, white visual tone from the current
  implementation. Do not reintroduce explanatory landing-page copy.

## Source Image Note

Some older Google Drive screen-design images still include wording or visual
areas that imply attendee selection. The fixed product rule overrides those
older labels: the implemented and accepted MVP must be project-only for meeting
context selection.

## Canva Usage Rule

Use the PPTX as the locked source when importing to Canva. Do not regenerate the
deck from a prompt unless the revision is explicitly marked as a new version.
For review comments, edit the imported Canva deck or update this fixed PPTX
source and regenerate the previews.

## Verification

- PPTX generated with `@oai/artifact-tool`.
- All 12 slides rendered to PNG previews.
- Layout JSON was exported for every slide.
- The final PPTX is a real `.pptx` file and contains embedded screen-design
  images from the local Google Drive folder.
- `scripts/smoke_canva_screen_design_fixed.sh` validates the PPTX, manifest,
  public handoff JSON, preview PNGs, layout JSON files, and fixed UI rules.
