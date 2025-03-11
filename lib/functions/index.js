const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

exports.autoReleaseSlots = functions.pubsub.schedule("every 10 minutes").onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const expiredBookings = await db.collection("bookings")
        .where("status", "==", "Pending")
        .where("created_at", "<=", now)
        .get();

    const batch = db.batch();

    expiredBookings.forEach((doc) => {
        const bookingData = doc.data();
        const slotRef = db.collection("charging_slots")
            .doc(bookingData.station_id)
            .collection("slots")
            .doc(bookingData.slot_id);

        batch.update(slotRef, { status: "available" });
        batch.update(doc.ref, { status: "Expired" });
    });

    await batch.commit();
    console.log(`Released ${expiredBookings.size} expired slots.`);
});
