# Ordered cast ownership policy (S85)
- CastOwner pure controller snapshots ordered starts; singleton start, reverse stop, rollback successful acquisitions, best-effort cleanup/reporting, reentrancy guards, old closure safety. Not live-wired.
- CHECK PASS: 586 pure/80 specs; seven owner cases; reverse-order/idempotence mutations detected/restored.
- Critical boundary: a failing start must unwind its own partially acquired resources. Controller can only release returned stop handles. Existing Receipt.start registers listeners before cleanup; Delivery/Contact can fail at Heartbeat registration. This is NOT solved by the pure controller.
- NEXT c3b1b: make each engine start exception-safe, compose prepared exclusive receipt/delivery/contact adapter with CastOwner, actual-source fault injection on all acquisitions; consumers stop before receipt inboxes. Then c3b2 atomic legacy replacement, then d2 visuals. Startup remains OFF.
