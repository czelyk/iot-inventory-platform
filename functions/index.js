const crypto = require("crypto");
const functions = require("firebase-functions/v1");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const authAdmin = getAuth();
const DEVICE_EMAIL_DOMAIN = "devices.smart-inventory.invalid";
const MAX_DEVICES_PER_USER = 10;
const DEVICE_ID_PATTERN = /^[A-F0-9]{32}$/;
const ALLOWED_WEB_ORIGINS = new Set([
  "https://smart-kuehlschrank81.web.app",
  "https://smart-kuehlschrank81.firebaseapp.com",
]);

/**
 * Returns whether a browser origin may call the provisioning endpoint.
 * @param {string|undefined} origin Request origin.
 * @return {boolean} Whether the origin is allowed.
 */
function isAllowedOrigin(origin) {
  if (!origin) return true;
  if (ALLOWED_WEB_ORIGINS.has(origin)) return true;
  return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
}

/**
 * Applies the endpoint's narrow CORS policy.
 * @param {object} request Express request.
 * @param {object} response Express response.
 * @return {boolean} Whether processing may continue.
 */
function setCorsHeaders(request, response) {
  const origin = request.get("origin");
  if (!isAllowedOrigin(origin)) return false;
  if (origin) {
    response.set("Access-Control-Allow-Origin", origin);
    response.set("Vary", "Origin");
  }
  response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  return true;
}

/**
 * Sends a stable error code without leaking internal exception details.
 * @param {object} response Express response.
 * @param {number} status HTTP status.
 * @param {string} code Stable client-facing error code.
 */
function sendError(response, status, code) {
  response.status(status).json({error: code});
}

/**
 * Verifies the caller and rejects unverified or device identities.
 * @param {object} request Express request.
 * @return {Promise<object|null>} Verified token or null.
 */
async function authenticatedUser(request) {
  const authorization = request.get("authorization") || "";
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization);
  if (!match) return null;

  try {
    const token = await authAdmin.verifyIdToken(match[1], true);
    if (token.email_verified !== true || token.device_id) return null;
    return token;
  } catch (_) {
    return null;
  }
}

/**
 * Derives a non-guessable Firebase Auth UID for a physical device.
 * @param {string} deviceId Physical device ID.
 * @return {{uid: string, email: string}} Device Auth identity.
 */
function deviceIdentity(deviceId) {
  const digest = crypto
      .createHash("sha256")
      .update(`${process.env.GCLOUD_PROJECT}:${deviceId}`)
      .digest("hex");
  return {
    uid: `device_${digest.slice(0, 32)}`,
    email: `device-${deviceId.toLowerCase()}@${DEVICE_EMAIL_DOMAIN}`,
  };
}

/**
 * Creates the owner document and initial platforms idempotently.
 * @param {{uid: string, email: (string|undefined)}} user Verified user.
 * @return {Promise<boolean>} Whether a profile was created.
 */
async function ensureUserProfile(user) {
  const userRef = db.collection("users").doc(user.uid);
  if ((await userRef.get()).exists) return false;

  const batch = db.batch();
  batch.set(userRef, {
    email: user.email || "",
    createdAt: FieldValue.serverTimestamp(),
    isPremium: false,
    languageCode: "en",
  }, {merge: true});

  const platformsRef = userRef.collection("platforms");
  for (let i = 1; i <= 10; i++) {
    batch.set(platformsRef.doc(`platform${i}`), {
      name: `Product Slot ${i}`,
      current_weight_kg: 0.0,
      category: "Other",
      status: i <= 2 ? "active" : "inactive",
      last_updated: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  await batch.commit();
  return true;
}

exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  if (!user.emailVerified ||
      (user.email && user.email.endsWith(`@${DEVICE_EMAIL_DOMAIN}`))) {
    return null;
  }

  const created = await ensureUserProfile(user);
  if (created) {
    functions.logger.info("Verified user profile created", {uid: user.uid});
  }
  return null;
});

exports.ensureUserProfile = functions.runWith({
  maxInstances: 10,
  memory: "256MB",
  timeoutSeconds: 30,
}).https.onRequest(async (
    request, response,
) => {
  response.set("Cache-Control", "no-store");
  response.set("X-Content-Type-Options", "nosniff");
  if (!setCorsHeaders(request, response)) {
    sendError(response, 403, "origin-not-allowed");
    return;
  }
  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }
  if (request.method !== "POST") {
    response.set("Allow", "POST, OPTIONS");
    sendError(response, 405, "method-not-allowed");
    return;
  }
  const contentLength = Number(request.get("content-length") || 0);
  if (contentLength > 2048) {
    sendError(response, 413, "request-too-large");
    return;
  }
  if (!request.is("application/json") ||
      !request.body ||
      typeof request.body !== "object" ||
      Array.isArray(request.body) ||
      Object.keys(request.body).length !== 0) {
    sendError(response, 400, "invalid-request");
    return;
  }

  const user = await authenticatedUser(request);
  if (!user) {
    sendError(response, 401, "authentication-required");
    return;
  }

  try {
    await ensureUserProfile({uid: user.uid, email: user.email});
    response.status(204).send("");
  } catch (error) {
    functions.logger.error("User profile initialization failed", {
      uid: user.uid,
      code: error.code || "unknown",
    });
    sendError(response, 500, "profile-initialization-failed");
  }
});

exports.provisionDevice = functions.runWith({
  maxInstances: 10,
  memory: "256MB",
  timeoutSeconds: 30,
}).https.onRequest(async (
    request, response,
) => {
  response.set("Cache-Control", "no-store");
  response.set("X-Content-Type-Options", "nosniff");

  if (!setCorsHeaders(request, response)) {
    sendError(response, 403, "origin-not-allowed");
    return;
  }
  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }
  if (request.method !== "POST") {
    response.set("Allow", "POST, OPTIONS");
    sendError(response, 405, "method-not-allowed");
    return;
  }
  if (!request.is("application/json")) {
    sendError(response, 415, "json-required");
    return;
  }

  const provisioningContentLength = Number(
      request.get("content-length") || 0,
  );
  if (provisioningContentLength > 2048) {
    sendError(response, 413, "request-too-large");
    return;
  }

  const user = await authenticatedUser(request);
  if (!user) {
    sendError(response, 401, "authentication-required");
    return;
  }

  const rawDeviceId = request.body && request.body.deviceId;
  if (!request.body ||
      typeof request.body !== "object" ||
      Array.isArray(request.body) ||
      Object.keys(request.body).some((key) => key !== "deviceId")) {
    sendError(response, 400, "invalid-request");
    return;
  }
  const deviceId = typeof rawDeviceId === "string" ?
    rawDeviceId.trim().toUpperCase() : "";
  if (!DEVICE_ID_PATTERN.test(deviceId)) {
    sendError(response, 400, "invalid-device-id");
    return;
  }

  const identity = deviceIdentity(deviceId);
  const registryRef = db.collection("deviceRegistry").doc(deviceId);
  const deviceRef = db.collection("users").doc(user.uid)
      .collection("devices").doc(deviceId);

  try {
    const existingDevices = await db.collection("users").doc(user.uid)
        .collection("devices").limit(MAX_DEVICES_PER_USER + 1).get();
    const alreadyOwned = existingDevices.docs.some(
        (doc) => doc.id === deviceId,
    );
    if (!alreadyOwned && existingDevices.size >= MAX_DEVICES_PER_USER) {
      sendError(response, 429, "device-limit-reached");
      return;
    }

    await db.runTransaction(async (transaction) => {
      const registry = await transaction.get(registryRef);
      if (registry.exists && registry.get("ownerUid") !== user.uid) {
        const error = new Error("device-already-owned");
        error.code = "device-already-owned";
        throw error;
      }
      const lastUpdate = registry.exists ? registry.get("updatedAt") : null;
      if (lastUpdate &&
          Date.now() - lastUpdate.toMillis() < 10000) {
        const error = new Error("provisioning-rate-limited");
        error.code = "provisioning-rate-limited";
        throw error;
      }
      transaction.set(registryRef, {
        ownerUid: user.uid,
        deviceUid: identity.uid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });

    const password = crypto.randomBytes(32).toString("base64url");
    const keyVersion = crypto.randomBytes(16).toString("hex");
    let deviceUser;
    try {
      deviceUser = await authAdmin.getUser(identity.uid);
      const claims = deviceUser.customClaims || {};
      if (claims.device_owner_uid && claims.device_owner_uid !== user.uid) {
        sendError(response, 409, "device-already-owned");
        return;
      }
      deviceUser = await authAdmin.updateUser(identity.uid, {
        password,
        disabled: false,
        emailVerified: true,
      });
      await authAdmin.revokeRefreshTokens(identity.uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
      deviceUser = await authAdmin.createUser({
        uid: identity.uid,
        email: identity.email,
        password,
        emailVerified: true,
      });
    }

    await authAdmin.setCustomUserClaims(deviceUser.uid, {
      device_id: deviceId,
      device_owner_uid: user.uid,
      device_key_version: keyVersion,
    });
    await deviceRef.set({
      deviceUid: deviceUser.uid,
      pairedAt: FieldValue.serverTimestamp(),
      status: "active",
      keyVersion,
      platformIds: ["platform1", "platform2"],
    }, {merge: true});

    response.status(200).json({
      deviceId,
      ownerUid: user.uid,
      email: identity.email,
      password,
    });
  } catch (error) {
    if (error.code === "device-already-owned") {
      sendError(response, 409, "device-already-owned");
      return;
    }
    if (error.code === "provisioning-rate-limited") {
      response.set("Retry-After", "10");
      sendError(response, 429, "provisioning-rate-limited");
      return;
    }
    functions.logger.error("Device provisioning failed", {
      uid: user.uid,
      deviceIdHash: crypto.createHash("sha256")
          .update(deviceId)
          .digest("hex")
          .slice(0, 12),
      code: error.code || "unknown",
    });
    sendError(response, 500, "provisioning-failed");
  }
});

exports.cleanupUserDevices = functions.auth.user().onDelete(async (user) => {
  if (user.email && user.email.endsWith(`@${DEVICE_EMAIL_DOMAIN}`)) {
    return null;
  }

  const devices = await db.collection("users").doc(user.uid)
      .collection("devices").get();
  await Promise.all(devices.docs.map(async (device) => {
    const deviceUid = device.get("deviceUid");
    if (typeof deviceUid === "string") {
      try {
        await authAdmin.deleteUser(deviceUid);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
    }
    await db.collection("deviceRegistry").doc(device.id).delete();
  }));
  await db.recursiveDelete(db.collection("users").doc(user.uid));
  return null;
});
