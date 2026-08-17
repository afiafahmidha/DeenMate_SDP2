const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// Limit the maximum number of containers that can run at the same time.
// This helps control unexpected costs during traffic spikes.
setGlobalOptions({maxInstances: 10});

exports.notifyGroupLeaderOfSos = onDocumentCreated(
    "emergencyGroups/{groupCode}/incidents/{incidentId}",
    async (event) => {
      const incident = event.data.data();
      const group = await admin.firestore()
          .doc(`emergencyGroups/${event.params.groupCode}`).get();
      const leaderId = group.data()?.leaderId;
      if (!leaderId || leaderId === incident.senderId) return;
      const leader = await admin.firestore().doc(`users/${leaderId}`).get();
      const tokens = leader.data()?.pushTokens || [];
      if (!tokens.length) return;
      const result = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Group SOS alert",
          body: `${incident.senderName || "A member"} needs help.`,
        },
        data: {
          groupCode: event.params.groupCode,
          incidentId: event.params.incidentId,
          route: "/sos",
        },
      });
      const invalid = result.responses
          .map((response, index) => response.success ? null : tokens[index])
          .filter(Boolean);
      if (invalid.length) {
        await leader.ref.update({pushTokens: admin.firestore.FieldValue.arrayRemove(...invalid)});
      }
    },
);
