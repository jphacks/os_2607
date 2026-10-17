# Backend implementation decisions — 2026-10-17

Read ../AGENTS.md and ../.codex/{README,architecture,domain,decisions,testing,phases/*} before implementation.
This app-local note supplements those repository-level documents.

- Explicit user request scopes this task to remote Supabase and iOS data access. Earlier phases are not claimed complete; no Encounter, SwiftData, AR, NI or Multipeer implementation is added.
- Auth user UUID is personID. Profile creation is explicit after a session exists (email confirmation may be required). Reinstall/multiple devices recover identity by logging into the same account.
- Auth user deletion cascades to profile and contents. No client profile-delete operation is exposed. Existing data is never removed by schema setup.
- `is_discoverable` is consent to disclose all base Profile fields to authenticated users. `is_public` additionally gates individual contents. PublicProfile excludes internal visibility/timestamps.
- `unlock_after_seconds` remains configurable metadata. This requested RLS gates consent, not Encounter elapsed time. Reveal integration and server-enforced time eligibility remain undecided; clients can retrieve permitted public values before the threshold. The example does not automatically display contents.
- Update inputs contain the full editable state. Optional nil values encode JSON null to clear values; they do not mean leave unchanged. IDs, ownership, and timestamps are not mutable DTO fields.
- URL content types (image/music/url/video) use HTTP(S) URLs. Storage object paths are not accepted as content URLs; avatarPath remains an optional path.
- Swift string limits count Unicode scalars to match PostgreSQL character counts, rather than Swift grapheme clusters.
- MainActor isolates repositories/API/Auth. Models and DTOs use Sendable value types. Target default isolation is nonisolated to match the SwiftPM verification target; SwiftUI retains its UI isolation.
- No cache is added. Fetch errors propagate; offline data freshness and revocation deadlines remain future Phase 4 work.
- SDK pinned to 2.49.0 for reproducibility. SwiftPM tests compile the same backend sources; they do not verify iOS/Xcode or real UWB.
