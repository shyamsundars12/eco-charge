const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.checkExpiredBookings = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  try {
    // Get all pending bookings that have expired
    const expiredBookingsSnapshot = await db.collection('bookings')
      .where('status', '==', 'pending')
      .where('expires_at', '<=', now)
      .get();

    // Process each expired booking
    const batch = db.batch();
    for (const doc of expiredBookingsSnapshot.docs) {
      const bookingData = doc.data();
      
      // Update booking status to expired
      batch.update(doc.ref, {
        'status': 'expired',
        'updated_at': now
      });

      // Update slot status back to available
      const slotRef = db.collection('charging_slots')
        .doc(bookingData.station_id)
        .collection('slots')
        .doc(bookingData.slot_id);

      batch.update(slotRef, {
        'status': 'available',
        'booked_by': null,
        'booking_id': null,
        'booked_at': null,
        'expires_at': null,
        'updated_at': now
      });
    }

    // Commit all updates
    await batch.commit();
    console.log(`Processed ${expiredBookingsSnapshot.size} expired bookings`);
  } catch (error) {
    console.error('Error processing expired bookings:', error);
  }
}); 