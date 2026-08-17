# Group SOS incident access review

## Data model

`emergencyGroups/{groupCode}/incidents/{incidentId}` contains the sender UID,
display name, live coordinates, an address, status, and server timestamps.
Only existing group members can read incident documents. The sender is the only
client allowed to change an active incident to `resolved`.

## Access checks reviewed

- Unauthenticated reads and writes: denied.
- Non-members reading or creating group incidents: denied by membership check.
- A member creating an incident for another UID: denied by `senderId == auth.uid`.
- A member resolving another user's incident: denied by the sender ownership
  check.
- A sender changing identity, location, address, or creation timestamp while
  resolving: denied by immutable-field checks.
- Arbitrary incident fields on resolution: denied by the strict allowed-key
  list.

The rules compiled successfully and were deployed to Firestore on 2026-08-18.
