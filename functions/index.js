const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();
  const userId = user.uid;
  const userRef = db.collection("users").doc(userId);

  try {
    // Toplu yazma (Batch Write) işlemi başlat
    const batch = db.batch();

    // 1. Ana kullanıcı dökümanını oluştur
    batch.set(userRef, {
      email: user.email || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isPremium: false,
    });

    // 2. Physical weighing platforms. The collection name is retained for
    // compatibility with already deployed ESP32 firmware.
    const platformsRef = userRef.collection("platforms");
    for (let i = 1; i <= 10; i++) {
      const platformId = `platform${i}`;
      const newPlatformRef = platformsRef.doc(platformId);

      batch.set(newPlatformRef, {
        name: `Product Slot ${i}`,
        current_weight_kg: 0.0,
        unit_weight_kg: null,
        minimum_stock_threshold: null,
        category: "Other",
        status: i <= 2 ? "active" : "inactive",
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 3. Generic restocking-list example.
    const shoppingListRef = userRef.collection("shopping_list").doc();
    batch.set(shoppingListRef, {
      name: "Brake cleaner spray",
      category: "Automotive",
      isBought: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Hepsini tek seferde kaydet
    await batch.commit();

    console.log(`User profile created for ${userId}`);
    return null;
  } catch (error) {
    console.error("Error creating user profile:", error);
    return null;
  }
});
