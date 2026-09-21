const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// Limit the maximum number of containers that can run at the same time.
// This helps control unexpected costs during traffic spikes.
setGlobalOptions({maxInstances: 10});

// Keep the existing deployed function ID so this is an in-place update,
// avoiding duplicate alerts from a second Firestore trigger.
exports.notifyGroupLeaderOfSos = onDocumentCreated(
    "emergencyGroups/{groupCode}/incidents/{incidentId}",
    async (event) => {
      const incident = event.data.data();
      const group = await admin.firestore()
          .doc(`emergencyGroups/${event.params.groupCode}`).get();
      if (!group.exists) return;

      // An SOS is for every other member of the emergency group, not merely
      // its leader. Member document IDs are Firebase Auth user IDs.
      const members = await group.ref.collection("members").get();
      const recipientIds = members.docs
          .map((member) => member.id)
          .filter((uid) => uid !== incident.senderId);
      if (!recipientIds.length) return;

      const recipients = await Promise.all(recipientIds.map((uid) =>
        admin.firestore().doc(`users/${uid}`).get()));
      const tokens = [...new Set(recipients.flatMap((user) => {
        const userData = user.data();
        return Array.isArray(userData && userData.pushTokens) ?
          userData.pushTokens : [];
      }))];
      if (!tokens.length) return;

      // FCM accepts at most 500 device tokens in one multicast request.
      const invalidTokens = [];
      for (let start = 0; start < tokens.length; start += 500) {
        const batch = tokens.slice(start, start + 500);
        const result = await admin.messaging().sendEachForMulticast({
          tokens: batch,
          notification: {
            title: "Group SOS alert",
            body: `${incident.senderName || "A member"} needs help.`,
          },
          data: {
            category: "sos",
            groupCode: event.params.groupCode,
            incidentId: event.params.incidentId,
            route: "/sos",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "deenmate_prayer_alarms",
              sound: "default",
            },
          },
          apns: {payload: {aps: {sound: "default"}}},
        });
        result.responses.forEach((response, index) => {
          const code = response.error && response.error.code;
          if (code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-registration-token") {
            invalidTokens.push(batch[index]);
          }
        });
      }

      if (invalidTokens.length) {
        await Promise.all(recipients.map((user) => user.ref.update({
          pushTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        })));
      }
    },
);
