# SOS Firestore security review

## SOS incident schema

`sosIncidents/{incidentId}` is owner-private and has only `ownerId`, `status`,
`latitude`, `longitude`, `address`, `isSilent`, `createdAt`, `updatedAt`, and
`resolvedAt`. Medical data and phone numbers are deliberately not stored here.

## Access checks reviewed

- An unauthenticated caller cannot read or write an incident.
- A different signed-in user cannot read, update, or delete an owner's incident.
- Creates require the caller's UID, bounded coordinates and address, server-time
  timestamps, and the initial `active` state.
- Updates preserve owner and creation time, validate the whole schema, and
  allow only `active` to `active`/`resolved` or a resolved record to remain
  resolved.
- Extra fields, overlong addresses, invalid types, and out-of-range coordinates
  are rejected by the validator used for both creates and updates.
- Deletes are denied so an incident retains its audit record.

## Remaining deployment check

Run `firebase deploy --only firestore:rules` while authenticated to the
`deenmate-be588` project, then test with two accounts and a real device.
