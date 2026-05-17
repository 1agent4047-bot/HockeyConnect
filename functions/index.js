const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret);

admin.initializeApp();
const db = admin.firestore();

// POST /createPaymentIntent
// Body: { gameId, trigger: "player_join"|"group_select", payerId }
exports.createPaymentIntent = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  const { gameId, trigger, payerId } = req.body;
  if (!gameId || !trigger || !payerId) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  try {
    const intent = await stripe.paymentIntents.create({
      amount: 500,           // $5.00 USD in cents
      currency: "usd",
      automatic_payment_methods: { enabled: true },
      metadata: { gameId, trigger, payerId },
    });

    // Pre-create the payment record as pending
    await db.collection("payments").add({
      payerId,
      amount: 500,
      trigger,
      gameId,
      stripePaymentIntentId: intent.id,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ clientSecret: intent.client_secret });
  } catch (err) {
    console.error("createPaymentIntent error:", err);
    res.status(500).json({ error: err.message });
  }
});

// Stripe webhook: mark payment completed and send push notifications
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      functions.config().stripe.webhook_secret
    );
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === "payment_intent.succeeded") {
    const intent = event.data.object;
    const { gameId, trigger, payerId } = intent.metadata;

    // Mark payment completed
    const snap = await db.collection("payments")
      .where("stripePaymentIntentId", "==", intent.id)
      .limit(1)
      .get();
    if (!snap.empty) {
      await snap.docs[0].ref.update({ status: "completed" });
    }

    // Send push notification to the other party
    const gameSnap = await db.collection("games").document(gameId).get();
    const game = gameSnap.data();
    if (!game) return res.json({ received: true });

    if (trigger === "player_join") {
      // Notify the group
      const groupSnap = await db.collection("users").document(game.groupId).get();
      const groupToken = groupSnap.data()?.fcmToken;
      if (groupToken) {
        await admin.messaging().send({
          token: groupToken,
          notification: {
            title: "New Player Applied!",
            body: "A player has applied to your game. Check your applicants.",
          },
          data: { gameId, type: "player_join" },
        });
      }
    } else if (trigger === "group_select") {
      // Notify the player
      const playerSnap = await db.collection("users").document(payerId).get();
      const playerToken = playerSnap.data()?.fcmToken;
      if (playerToken) {
        await admin.messaging().send({
          token: playerToken,
          notification: {
            title: "You've Been Selected!",
            body: `${game.groupName} has selected you for their game at ${game.rinkName}.`,
          },
          data: { gameId, type: "group_select" },
        });
      }
    }
  }

  res.json({ received: true });
});
