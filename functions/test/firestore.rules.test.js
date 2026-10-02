const fs = require("fs");
const path = require("path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} = require("firebase/firestore");

const PROJECT_ID = "demo-smart-inventory-security";
const DEVICE_ID = "0123456789ABCDEF0123456789ABCDEF";
let environment;

before(async () => {
  const rules = fs.readFileSync(
      path.resolve(__dirname, "../../firestore.rules"),
      "utf8",
  );
  environment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {rules},
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await setDoc(doc(database, "users/owner"), {
      email: "owner@example.com",
      languageCode: "en",
    });
    await setDoc(doc(database, "users/owner/platforms/platform1"), {
      name: "Fasteners",
      category: "Hardware",
      current_weight_kg: 1,
      status: "active",
      last_updated: Timestamp.now(),
    });
    await setDoc(doc(database, "users/owner/platforms/platform3"), {
      name: "Unassigned",
      category: "Other",
      current_weight_kg: 0,
      status: "active",
      last_updated: Timestamp.now(),
    });
    await setDoc(doc(database, `users/owner/devices/${DEVICE_ID}`), {
      deviceUid: "sensor",
      keyVersion: "0123456789abcdef0123456789abcdef",
      platformIds: ["platform1", "platform2"],
      status: "active",
    });
  });
});

after(async () => {
  await environment.cleanup();
});

test("only a verified owner can read their inventory", async () => {
  const owner = environment.authenticatedContext("owner", {
    email_verified: true,
  }).firestore();
  const unverified = environment.authenticatedContext("owner", {
    email_verified: false,
  }).firestore();
  const attacker = environment.authenticatedContext("attacker", {
    email_verified: true,
  }).firestore();
  const platformPath = "users/owner/platforms/platform1";

  await assertSucceeds(getDoc(doc(owner, platformPath)));
  await assertFails(getDoc(doc(unverified, platformPath)));
  await assertFails(getDoc(doc(attacker, platformPath)));
});

test("owners can configure products but cannot forge sensor data", async () => {
  const owner = environment.authenticatedContext("owner", {
    email_verified: true,
  }).firestore();
  const platform = doc(owner, "users/owner/platforms/platform1");

  await assertSucceeds(updateDoc(platform, {
    name: "Bolts",
    category: "Hardware",
    configuration_updated_at: serverTimestamp(),
  }));
  await assertFails(updateDoc(platform, {
    current_weight_kg: 999,
    last_updated: serverTimestamp(),
  }));
});

test("a paired sensor can update readings but not configuration", async () => {
  const sensor = environment.authenticatedContext("sensor", {
    device_id: DEVICE_ID,
    device_key_version: "0123456789abcdef0123456789abcdef",
    device_owner_uid: "owner",
  }).firestore();
  const platform = doc(sensor, "users/owner/platforms/platform1");

  await assertSucceeds(updateDoc(platform, {
    current_weight_kg: 2.5,
    last_updated: serverTimestamp(),
  }));
  await assertFails(updateDoc(platform, {
    name: "Tampered",
    configuration_updated_at: serverTimestamp(),
  }));
  await assertFails(updateDoc(
      doc(sensor, "users/owner/platforms/platform3"),
      {
        current_weight_kg: 2.5,
        last_updated: serverTimestamp(),
      },
  ));
});

test("an unpaired device identity cannot submit readings", async () => {
  const sensor = environment.authenticatedContext("other-sensor", {
    device_id: DEVICE_ID,
    device_key_version: "0123456789abcdef0123456789abcdef",
    device_owner_uid: "owner",
  }).firestore();

  await assertFails(updateDoc(
      doc(sensor, "users/owner/platforms/platform1"),
      {
        current_weight_kg: 2.5,
        last_updated: serverTimestamp(),
      },
  ));
});

test("shopping-list writes enforce schema and size limits", async () => {
  const owner = environment.authenticatedContext("owner", {
    email_verified: true,
  }).firestore();

  await assertSucceeds(setDoc(doc(owner, "users/owner/shopping_list/good"), {
    name: "Brake cleaner",
    category: "Automotive",
    isBought: false,
    createdAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(owner, "users/owner/shopping_list/bad"), {
    name: "x".repeat(101),
    category: "Unsupported",
    isBought: false,
    createdAt: serverTimestamp(),
    injected: true,
  }));
});
