# DeenMate Firestore Structure

DeenMate uses Cloud Firestore as a document-oriented NoSQL database. Private
records are scoped below `users/{uid}` and shared resources use root-level
collections with ownership and membership checks.

## Users and personal features

### `users/{uid}`

Typical fields: `name`, `email`, `phone`, `language`, `theme`, `profile`, and
legacy feature maps.

| Path | Main fields | Cardinality |
|---|---|---|
| `users/{uid}/quranTracker/{docId}` | `streak`, `completedAyahsToday`, `lastReadAyah`, `juz`, `date`, `lastUpdated` | Many state/progress documents |
| `users/{uid}/dhikrStats/{docId}` | `lifetimeTotal`, `dailyHistory`, `presets`, `lastUpdated` | User statistics |
| `users/{uid}/hajjProgress/{journeyId}` | `hajjType`, `steps`, `ritualDone`, `packing`, `documents`, `history` | Hajj journeys |
| `users/{uid}/prayerPreferences/{preferenceId}` | `method`, `madhhab`, `location` | Prayer preferences |
| `users/{uid}/notifications/{notificationId}` | `type`, `title`, `body`, `read`, `createdAt` | User notifications |
| `users/{uid}/aiChats/{chatId}` | `title`, `messages`, `createdAt`, `updatedAt` | AI conversations |

## Zakat and inheritance

| Path | Main fields |
|---|---|
| `users/{uid}/zakatProfiles/{profileId}` | `currency`, `nisaabBasis`, `goldPrice`, `silverPrice`, `cash`, `gold`, `silver`, `stocks`, `business`, `liabilities`, `customAssets`, `hawlStartDate`, `zakatDue`, `ushrItems`, `rikazItems`, `lastUpdated` |
| `users/{uid}/inheritanceScenarios/{scenarioId}` | `familyTree`, `myGender`, `estateValue`, `debts`, `willAmount`, `savedScenarios`, `lockedMatrix`, `lastUpdated` |

Ushr and Rikaz are stored in the Zakat profile as structured maps/lists. They
may later be normalized into `ushrItems/{itemId}` and `rikazItems/{itemId}` if
individual editing or audit history is required.

## Halal scanner

| Path | Main fields | Purpose |
|---|---|---|
| `users/{uid}/halalScans/{scanId}` | `barcode`, `productName`, `ingredients`, `additives`, `halalStatus`, `resultDetails`, `analysisResults`, `imageUrl`, `packagePhotoUrl`, `certificationUrl`, `source`, `scannedAt` | Private scan history |
| `halalProducts/{barcode}` | `barcode`, `productName`, `ingredients`, `additives`, `halalStatus`, `submittedBy`, `moderationStatus`, `imageUrl`, `certificationImageUrl`, `createdAt`, `updatedAt` | Shared community catalogue |

Open Food Facts is checked first. If a barcode is not found there, the
community product document allows another account to retrieve the submitted
product using the same barcode.

## Emergency SOS

| Path | Main fields |
|---|---|
| `emergencyGroups/{groupCode}` | `code`, `name`, `leaderId`, `leaderName`, `rangeMeters`, `createdAt`, `updatedAt` |
| `emergencyGroups/{groupCode}/members/{uid}` | `name`, `photoUrl`, `phoneBase64`, `isLeader`, `joinedAt`, `latitude`, `longitude` |
| `emergencyGroups/{groupCode}/messages/{messageId}` | `sender`, `body`, `createdAt` |
| `emergencyGroups/{groupCode}/incidents/{incidentId}` | `ownerId`, `status`, `latitude`, `longitude`, `address`, `isSilent`, `createdAt`, `updatedAt`, `resolvedAt` |
| `sosIncidents/{incidentId}` | Same incident summary and `ownerId` | Root incident index |

The group incident and root incident index represent the same SOS event and
must share a stable `incidentId`.

## Qurbani collaboration

| Path | Main fields |
|---|---|
| `users/{ownerUid}/qurbaniPlans/{planId}` | `ownerId`, `ownerName`, `year`, `status`, `animalType`, `totalShares`, `myShares`, `memberIds`, `inviteCode`, `estimatedCost`, `paidAmount`, `slaughterDate`, `notes`, `createdAt`, `updatedAt` |
| `users/{ownerUid}/qurbaniPlans/{planId}/members/{memberId}` | `name`, `shares`, `phone`, `amountDue`, `amountPaid`, `paymentStatus`, `uid` |
| `users/{ownerUid}/qurbaniPlans/{planId}/participants/{participantId}` | Participant and share details |
| `users/{ownerUid}/qurbaniPlans/{planId}/expenses/{expenseId}` | `category`, `amount`, `notes`, `payers`, `ownerId` |
| `users/{ownerUid}/qurbaniPlans/{planId}/messages/{messageId}` | `sender`, `content`, `createdAt` |
| `users/{ownerUid}/qurbaniPlans/{planId}/settlements/{settlementId}` | `fromId`, `toId`, `amount`, `confirmed`, `date` |
| `users/{ownerUid}/qurbaniPlans/{planId}/editRequests/{requestId}` | Edit request details |
| `users/{ownerUid}/qurbaniPlans/{planId}/checklist/{itemId}` | `done` |
| `users/{ownerUid}/qurbaniPlans/{planId}/yearlyArchive/{archiveId}` | Archived plan data |
| `qurbaniPlanInvites/{code}` | `ownerUid`, `planId`, `createdAt`, `expiresAt` |
| `qurbaniSharePosts/{postId}` | `posterId`, `title`, `animalType`, `description`, `createdAt` |
| `qurbaniSharePosts/{postId}/responses/{responseId}` | `responderId`, `name`, `message`, `status`, `createdAt` |

## Support

`support_messages/{messageId}` stores `userId`, `subject`, `message`, `status`
and `createdAt`.

## Relationship and security rules

- A user owns their private `users/{uid}` tree.
- A Qurbani plan has many members, participants, expenses, messages and
  settlements.
- An emergency group has many members, messages and incidents.
- A barcode maps to one shared `halalProducts/{barcode}` document.
- Private reads and writes require `request.auth.uid == uid`.
- Qurbani access requires plan membership or ownership.
- Emergency access requires group membership or leadership.
- Community Halal products should require authentication, validation and
  moderation before public approval.
- Invite codes should support exact document lookup, not unrestricted listing.
