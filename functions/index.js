const {setGlobalOptions} = require("firebase-functions");

// Limit the maximum number of containers that can run at the same time.
// This helps control unexpected costs during traffic spikes.
setGlobalOptions({maxInstances: 10});
