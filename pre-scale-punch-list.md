# Pre-Scale Punch List — The Book Was Better

Things flagged in earlier sessions as worth doing before opening the app up to a larger user base. Nothing here is built yet unless noted.

## 1. Activity log cleanup
Activity entries currently rely on a client-side `.limit(20)` read cap with no server-side purge. At scale the collection grows unbounded, costing storage and (eventually) read efficiency. Add a weekly scheduled Cloud Function that batch-deletes old activity entries — a batch job barely touches the free tier even at scale, so no need to trim on every write.

## 2. Duplicate club-document listener
`ClubDetailScreen` keeps its own `_clubSub` stream subscription on top of the one `StateModel._listenToClubs` already maintains, so every club update costs 2 reads instead of 1. Fix: drop `_clubSub` and have the screen read the live club from `StateModel`'s `_clubs` list instead.

## 3. Owner succession / election system
No safeguard exists today if a club owner goes unresponsive and can't be reached to transfer ownership or leave. Three options were discussed, increasing in cost:
- Block an owner from leaving without transferring ownership first (cheap, immediate, not yet built)
- Cloud Function auto-promotes the oldest member after some inactivity window
- Full election system: an `elections` subcollection plus a scheduled Cloud Function to tally votes

Verdict at the time: worth building once the core app is more complete, not urgent for an initial wider release but a gap worth closing before clubs have real, less-attentive owners.

## 4. Chat message retention
Messages are meant to be retained ~2 weeks. Only the client-side query/UI respects that window — there's no scheduled Cloud Function actually deleting messages older than 14 days, so the collection grows indefinitely server-side. Same fix pattern as #1: a weekly scheduled purge function.

## 5. Chat stream hoisting (already done — flag for revisit)
The message stream was deliberately moved from being local to the chat tab up to the parent club screen, so an unread-message badge can show from any tab. That's a real trade: a small but permanent increase in Firestore reads even when the user isn't in the chat tab, taken on purpose for the UX win. Worth revisiting if read volume becomes a real cost once usage grows — e.g. comparing message counts or `lastReadAt` timestamps instead of keeping the full stream open everywhere.

---

*Compiled from discussion in a prior debugging session ("User clubs display issue"). None of items 1–4 have been implemented; item 5 is live in the current code.*
