# Qurbani Planner Firestore security review

## Scope and observed access patterns

- Flutter app uses Firebase Auth and Cloud Firestore (Standard rules syntax).
- `users/{uid}` contains private profile and app-preference data and remains owner-only.
- Qurbani plans are stored at `users/{ownerUid}/qurbaniPlans/{planId}`.
- The app creates a plan with an authenticated owner, then reads plan subcollections using ordered streams:
  `participants` by `name`, `expenses` and `editRequests` by `createdAt`, and `settlements` by `date`.
- Participants, expenses, settlements, checklist state, and edit requests are read and written beneath a plan. Membership records grant shared-plan access.
- Invite documents are fetched by an exact code; the app never lists invite codes.
- The creator is the plan owner. Their persistent `inviteCode` is stored on the
  plan, and the member roster is stored in `members/{uid}`.

## Prototype rule decisions

- Default access remains denied unless a match explicitly allows it.
- A plan can be created only under the authenticated user's own document, and its initial membership contains only that owner.
- The owner exclusively manages plan metadata and `memberIds`; plan members may work with validated subcollection records.
- Plan members can only modify records they created, except for the planner's
  computed participant balance fields; the plan owner may manage all records.
- Settlements are append-only after creation, preventing a member from
  rewriting another household member's recorded payment.
- User profile documents are not exposed to plan members, avoiding private profile/PII disclosure.
- Qurbani uses the same group-code pattern as Emergency SOS. A signed-in user
  who has an exact code creates only their own membership document; they cannot
  edit the plan or another member's record.
- Only the plan owner can create an invite document, and it must point to a
  plan below that owner's user path.
- Owners may delete their own invite document and plan. A departing member may
  delete only their own membership document; they cannot delete the plan.

## Rule review attack checklist

- Unauthenticated plan/invite reads and writes: denied.
- Cross-user access to private `users/{uid}` documents: denied.
- Non-owner creation of a plan below another user: denied.
- Non-owner plan-metadata escalation: denied because only the plan owner can
  update a plan. A joiner may create only their own membership document after
  learning a valid code; the invite lookup is intentionally exact-code only.
- Group deletion by a non-owner: denied. Invite deletion is restricted to the
  invite's recorded owner, and members can only remove their own membership.
- Ownership/creation timestamp mutation: denied on plan, participant, and expense updates where those fields apply.
- Oversized or schema-polluting plan, participant, expense, settlement, and edit-request records: denied by key/type/size validators.
- Invite enumeration: denied (`list` is false); only exact-code fetches by
  signed-in users are allowed.
