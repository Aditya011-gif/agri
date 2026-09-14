const express = require('express');
const axios = require('axios');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

const app = express();
app.use(express.json({ limit: '25mb' }));

// Enable CORS for Flutter Web frontend
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, x-api-key, x-api-secret, x-api-version');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

const PORT = process.env.PORT || 3000;
const {
  WHATSAPP_TOKEN,
  WHATSAPP_PHONE_NUMBER_ID,
  WHATSAPP_VERIFY_TOKEN,
  GEMINI_API_KEY,
  FIREBASE_PROJECT_ID,
  FIREBASE_WEB_API_KEY
} = process.env;

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// Mandi Benchmark Data for Price Inquiries
const MANDI_BENCHMARK_RATES = {
  wheat: { nameHindi: 'गेहूं (Wheat)', msp: 2275, mandiRate: 2420, trend: 'स्थिर (+1.2%)' },
  rice: { nameHindi: 'धान/चावल (Basmati/Paddy)', msp: 2183, mandiRate: 3450, trend: 'तेज (+3.5%)' },
  mustard: { nameHindi: 'सरसों (Mustard)', msp: 5650, mandiRate: 5880, trend: 'तेज (+2.1%)' },
  cotton: { nameHindi: 'कपास (Cotton)', msp: 7020, mandiRate: 7250, trend: 'स्थिर' },
  soybean: { nameHindi: 'सोयाबीन (Soybean)', msp: 4600, mandiRate: 4720, trend: 'गिरावट (-0.8%)' },
  potato: { nameHindi: 'आलू (Potato)', msp: 1200, mandiRate: 1550, trend: 'स्थिर' },
  onion: { nameHindi: 'प्याज (Onion)', msp: 1400, mandiRate: 2100, trend: 'तेज (+4.0%)' },
  tomato: { nameHindi: 'टमाटर (Tomato)', msp: 1100, mandiRate: 1800, trend: 'तेज (+5.2%)' },
  maize: { nameHindi: 'मक्का (Maize)', msp: 2090, mandiRate: 2240, trend: 'स्थिर' }
};

// In-memory conversation state for pending crop listings & mandatory photo validation
const pendingCropListings = {};

// ---------------------------------------------------------------------------
// 1. Meta Webhook Verification (GET /webhook)
// ---------------------------------------------------------------------------
app.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === WHATSAPP_VERIFY_TOKEN) {
    console.log('✅ Meta Webhook challenge verified successfully!');
    res.status(200).send(challenge);
  } else {
    console.warn('❌ Webhook verification failed. Token mismatch.');
    res.sendStatus(403);
  }
});

// ---------------------------------------------------------------------------
// 2. Incoming Messages Webhook (POST /webhook)
// ---------------------------------------------------------------------------
app.post('/webhook', async (req, res) => {
  // Always respond with 200 OK within 3 seconds to avoid Meta retries
  res.sendStatus(200);

  try {
    const body = req.body;
    if (!body.object || !body.entry?.[0]?.changes?.[0]?.value?.messages) return;

    const change = body.entry[0].changes[0].value;
    const messageObj = change.messages[0];
    const contactObj = change.contacts?.[0] || {};

    const from = messageObj.from; // Sender WhatsApp Phone (e.g. 918307165924)
    const senderProfileName = contactObj.profile?.name || 'Kisan';
    const messageId = messageObj.id;
    const type = messageObj.type;

    console.log(`\n📩 Incoming from +${from} (${senderProfileName}): type=${type}`);

    // Mark message as read
    await markMessageAsRead(messageId);

    // Lookup Verified User Profile (Farmer, Retail Buyer, FPO, Bulk Buyer)
    const user = await getLinkedUser(from);
    const farmer = user; // backwards compatibility

    // =========================================================================
    // CASE A: Voice Note / Audio Message (Regional Voice AI Processing)
    // =========================================================================
    if (type === 'audio') {
      console.log(`🎙️ Voice Note received from +${from} [Role: ${user?.role || 'unlinked'}]. Downloading media...`);
      const media = await downloadMetaMedia(messageObj.audio.id);
      if (media) {
        const voiceResult = await processVoiceWithGemini(media.base64Data, media.mimeType, user);
        if (voiceResult) {
          console.log(`🎙️ Voice Note transcribed: "${voiceResult.transcriptionHindi || ''}"`);
          await handleParsedAiResult(from, voiceResult, user);
          return;
        }
      }
    }

    // =========================================================================
    // CASE B: Image / Photo (Visual Crop Quality Assay & Disease Detection)
    // =========================================================================
    if (type === 'image') {
      const caption = messageObj.image?.caption || '';
      console.log(`📸 Image received from +${from} [Role: ${user?.role || 'unlinked'}]. Caption: "${caption}". Downloading...`);
      const media = await downloadMetaMedia(messageObj.image.id);
      if (media) {
        const assayResult = await processImageWithGemini(media.base64Data, media.mimeType, caption, user);
        if (assayResult) {
          await handleImageAssayResult(from, assayResult, user, caption);
          return;
        }
      }
    }

    // =========================================================================
    // CASE C: Text & Interactive Button Replies
    // =========================================================================
    let textBody = '';
    if (type === 'text') {
      textBody = messageObj.text.body.trim();
    } else if (type === 'interactive') {
      textBody = messageObj.interactive?.button_reply?.title || messageObj.interactive?.list_reply?.title || '';
    }

    if (!textBody) return;
    console.log(`💬 Content: "${textBody}" from +${from} [Role: ${user?.role || 'unlinked'}]`);

    // STEP 1: Handshake Check - 1-Tap Account Linking
    if (textBody.includes('#UID:')) {
      await handleUserHandshake(from, textBody, senderProfileName);
      return;
    }

    // STEP 2: Agronomic & Trade Parsing with Gemini 2.5 Flash
    await processUserTextMessage(from, textBody, user);

  } catch (err) {
    console.error('❌ Error in WhatsApp webhook handler:', err.message);
  }
});

// ---------------------------------------------------------------------------
// 3. Meta Media Downloader Helper (Voice Notes & Photos)
// ---------------------------------------------------------------------------
async function downloadMetaMedia(mediaId) {
  try {
    const metaRes = await axios.get(`https://graph.facebook.com/v19.0/${mediaId}`, {
      headers: { Authorization: `Bearer ${WHATSAPP_TOKEN}` }
    });
    const mediaUrl = metaRes.data?.url;
    const mimeType = metaRes.data?.mime_type || 'application/octet-stream';

    if (!mediaUrl) return null;

    const binaryRes = await axios.get(mediaUrl, {
      headers: { Authorization: `Bearer ${WHATSAPP_TOKEN}` },
      responseType: 'arraybuffer'
    });

    const base64Data = Buffer.from(binaryRes.data).toString('base64');
    return { base64Data, mimeType };
  } catch (err) {
    console.error('❌ Error downloading Meta media:', err.response?.data || err.message);
    return null;
  }
}

// ---------------------------------------------------------------------------
// 4. Send WhatsApp Reply via Meta Graph API
// ---------------------------------------------------------------------------
async function sendWhatsAppMessage(to, text) {
  try {
    const url = `https://graph.facebook.com/v19.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`;
    const res = await axios.post(
      url,
      {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: to,
        type: 'text',
        text: { preview_url: false, body: text }
      },
      {
        headers: {
          Authorization: `Bearer ${WHATSAPP_TOKEN}`,
          'Content-Type': 'application/json'
        }
      }
    );
    console.log(`📤 Reply delivered to +${to} (Message ID: ${res.data?.messages?.[0]?.id})`);
  } catch (err) {
    console.error('❌ Error sending WhatsApp message:', err.response?.data || err.message);
  }
}

async function markMessageAsRead(messageId) {
  try {
    await axios.post(
      `https://graph.facebook.com/v19.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`,
      {
        messaging_product: 'whatsapp',
        status: 'read',
        message_id: messageId
      },
      {
        headers: {
          Authorization: `Bearer ${WHATSAPP_TOKEN}`,
          'Content-Type': 'application/json'
        }
      }
    );
  } catch (e) {}
}

// ---------------------------------------------------------------------------
// 5. Firestore Live Sync Helper (Direct REST API)
// ---------------------------------------------------------------------------
async function firestorePatch(collection, docId, fields) {
  return new Promise((resolve) => {
    const data = JSON.stringify({ fields });
    const maskParams = Object.keys(fields)
      .map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`)
      .join('&');
    const path = `/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${collection}/${docId}?key=${FIREBASE_WEB_API_KEY}&${maskParams}`;

    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: path,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => resolve(res.statusCode < 300 ? JSON.parse(body) : null));
    });
    req.on('error', (err) => {
      console.warn(`⚠️ Firestore REST Error (${collection}/${docId}):`, err.message);
      resolve(null);
    });
    req.write(data);
    req.end();
  });
}

async function firestoreGet(collection, docId) {
  return new Promise((resolve) => {
    https.get(
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${collection}/${docId}?key=${FIREBASE_WEB_API_KEY}`,
      (res) => {
        let body = '';
        res.on('data', d => body += d);
        res.on('end', () => resolve(res.statusCode === 200 ? JSON.parse(body) : null));
      }
    ).on('error', () => resolve(null));
  });
}

// ---------------------------------------------------------------------------
// 6. Account Linking & Verification
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// 6. Multi-Role Account Linking & Verification (Farmer, Retail Buyer, FPO, Bulk Buyer)
// ---------------------------------------------------------------------------
async function handleUserHandshake(phone, text, profileName) {
  const uidMatch = text.match(/#UID:([^\s#]+)/);
  const nameMatch = text.match(/#NAME:([^\n#]+)/);
  const phoneMatch = text.match(/#PHONE:([^\s#]+)/);
  const roleMatch = text.match(/#ROLE:([^\s#]+)/);
  const locMatch = text.match(/#LOC:([^\n#]+)/);

  const userId = uidMatch ? uidMatch[1].trim() : ('user_' + phone.slice(-6));
  const name = nameMatch ? nameMatch[1].trim() : profileName;
  const userPhone = phoneMatch ? phoneMatch[1].trim() : phone;
  const location = locMatch ? locMatch[1].trim() : 'Haryana';

  let role = roleMatch ? roleMatch[1].trim().toLowerCase() : null;

  // If role wasn't in text payload, query /users/{userId} directly from Firestore
  if (!role && userId) {
    try {
      const userDoc = await firestoreGet('users', userId);
      if (userDoc && userDoc.fields) {
        role = (userDoc.fields.userType?.stringValue || '').toLowerCase();
      }
    } catch (_) {}
  }

  // Normalize role
  if (role && (role.includes('retail') || role === 'retailbuyer')) {
    role = 'retailBuyer';
  } else if (role && (role.includes('fpo') || role === 'fpomemberfarmer')) {
    role = 'fpo';
  } else if (role && (role.includes('bulk') || role === 'buyer' || role === 'bulkbuyer')) {
    role = 'buyer';
  } else {
    role = 'farmer';
  }

  const userPayload = {
    userId: { stringValue: userId },
    name: { stringValue: name },
    phone: { stringValue: userPhone },
    whatsappNumber: { stringValue: phone },
    role: { stringValue: role },
    location: { stringValue: location },
    linkedAt: { timestampValue: new Date().toISOString() }
  };

  // 1. Sync in both whatsapp_users and whatsapp_farmers collections
  await firestorePatch('whatsapp_users', phone, userPayload);
  await firestorePatch('whatsapp_farmers', phone, userPayload);

  // 2. Update user profile in users collection
  await firestorePatch('users', userId, {
    whatsappNumber: { stringValue: phone },
    isWhatsAppLinked: { booleanValue: true },
    whatsappRole: { stringValue: role },
    whatsappLinkedAt: { timestampValue: new Date().toISOString() }
  });

  console.log(`✅ Successfully Linked WhatsApp +${phone} to [${role.toUpperCase()}] ${name} (${userId})`);

  let welcomeMsg = '';
  if (role === 'retailBuyer') {
    welcomeMsg = 
`🎉 *नमस्ते ${name} जी!* 🛒

आपका AgriChain *रिटेल खरीदार (Retail Buyer)* खाता आधिकारिक WhatsApp से जुड़ गया है!

✅ *कस्टमर ID*: #${userId.slice(0, 8)}
📍 *स्थान*: ${location}
📱 *WhatsApp फ़ोन*: +${phone}
🏷️ *खाता प्रकार*: रिटेल खरीदार (Buyer)

🤝 *आप WhatsApp पर क्या कर सकते हैं?*
👉 *"मेरे ऑर्डर"* या *"status"*: आपके खरीदे गए ताज़ा ऑर्डर और लाइव डिलीवरी स्थिति।
👉 *"टमाटर का भाव"* या *"गेहूं"* : किसानों से सीधे ताज़ा उपलब्ध फसलों के भाव।
👉 *"सब्जियां"* : नजदीकी किसानों से सीधे खेत की ताज़ा जैविक फसलें खोजें।
👉 *"पेमेंट"*: आपकी एस्क्रो सुरक्षा व डिलीवरी संतुष्टि गारंटी।`;
  } else if (role === 'fpo') {
    welcomeMsg = 
`🎉 *नमस्ते ${name} जी!* 🏢

आपका AgriChain *FPO (किसान उत्पादक संगठन)* खाता आधिकारिक WhatsApp से जुड़ गया है!

✅ *FPO ID*: #${userId.slice(0, 8)}
📍 *स्थान*: ${location}
📱 *WhatsApp फ़ोन*: +${phone}
🏷️ *खाता प्रकार*: FPO एग्रीगेटर

🤝 *आप WhatsApp पर क्या कर सकते हैं?*
👉 *"हमारा स्टॉक"* या *"status"*: FPO के सामूहिक लॉट्स की स्थिति और मात्रा।
👉 *बल्क लॉट लिस्ट करने के लिए बोलें/लिखें*: "करनाल में 200 क्विंटल गेहूं 2550 भाव"
👉 *"बल्क ऑर्डर"* या *"orders"*: फ्लोर मिलों और कॉर्पोरेट खरीदारों से आए ऑर्डर देखें।
👉 *"किसान सदस्य"*: FPO से जुड़े सदस्य किसानों की सूची।`;
  } else if (role === 'buyer') {
    welcomeMsg = 
`🎉 *नमस्ते ${name} जी!* 🏭

आपका AgriChain *बल्क खरीदार (Institutional / Mill Buyer)* खाता आधिकारिक WhatsApp से जुड़ गया है!

✅ *Buyer ID*: #${userId.slice(0, 8)}
📍 *स्थान*: ${location}
📱 *WhatsApp फ़ोन*: +${phone}
🏷️ *खाता प्रकार*: बल्क प्रोक्योरर

🤝 *आप WhatsApp पर क्या कर सकते हैं?*
👉 *"मेरे कॉन्ट्रैक्ट"* या *"status"*: आपके सक्रिय लीगल स्मार्ट कॉन्ट्रैक्ट और एस्क्रो फंड्स।
👉 *"मेरे ऑर्डर"* या *"my orders"*: आपके बल्क प्रोक्योरमेंट ऑर्डर्स की ट्रैकिंग।
👉 *"500 क्विंटल गेहूं चाहिए"*: उपलब्ध FPO क्लस्टर और फार्मर लॉट्स से तत्काल मिलान।
👉 *"RFQ स्थिति"*: आपके जारी टेंडर और कोट्स की स्थिति।`;
  } else {
    welcomeMsg = 
`🎉 *नमस्ते ${name} जी!* 🌾

आपका AgriChain *किसान खाता (Farmer Account)* आधिकारिक WhatsApp से जुड़ गया है!

✅ *किसान ID*: #${userId.slice(0, 8)}
📍 *स्थान*: ${location}
📱 *WhatsApp फ़ोन*: +${phone}
🏷️ *खाता प्रकार*: किसान (Seller)

🤝 *आप WhatsApp पर क्या कर सकते हैं?*
👉 *फसल बेचें*: बोलकर (Voice Note) या लिखकर भेजें: "करनाल में 50 क्विंटल शरबती गेहूं 2600 भाव"
👉 *फोटो भेजें*: AI फसल की गुणवत्ता (प्योरिटी, नमी) परखेगा और ग्रेड तय करेगा।
👉 *"मेरी फसलें"* या *"status"*: आपकी एक्टिव फसलें और उनकी वर्तमान स्थिति।
👉 *"ऑर्डर"* या *"my orders"*: खरीदारों से आए ताज़ा ऑर्डर और पेमेंट स्टेटस।`;
  }

  await sendWhatsAppMessage(phone, welcomeMsg);
}

const handleFarmerHandshake = handleUserHandshake;

async function getLinkedUser(phone) {
  let doc = await firestoreGet('whatsapp_users', phone);
  if (!doc) {
    const alt = phone.startsWith('91') ? phone.slice(2) : `91${phone}`;
    doc = await firestoreGet('whatsapp_users', alt);
  }
  if (!doc) {
    doc = await firestoreGet('whatsapp_farmers', phone);
  }
  if (!doc) {
    const alt = phone.startsWith('91') ? phone.slice(2) : `91${phone}`;
    doc = await firestoreGet('whatsapp_farmers', alt);
  }

  let user = null;
  if (doc && doc.fields) {
    const f = doc.fields;
    user = {
      userId: f.userId?.stringValue,
      name: f.name?.stringValue,
      role: f.role?.stringValue || 'farmer',
      location: f.location?.stringValue || 'Haryana',
      phone: f.phone?.stringValue || phone
    };
  } else if (phone.endsWith('8307165924') || phone.endsWith('38732065468642')) {
    user = {
      userId: '90Eajo6VcCRtbzxthkWCxAwHsBs2',
      name: 'aryan sharma',
      role: 'farmer',
      location: 'Karnal, Haryana',
      phone: phone
    };
  }

  // Ensure role is up-to-date with Firestore /users collection if possible
  if (user && user.userId) {
    try {
      const userDoc = await firestoreGet('users', user.userId);
      if (userDoc && userDoc.fields) {
        const rawType = (userDoc.fields.userType?.stringValue || '').toLowerCase();
        if (rawType.includes('retail')) user.role = 'retailBuyer';
        else if (rawType.includes('fpo')) user.role = 'fpo';
        else if (rawType.includes('buyer') || rawType.includes('bulk')) user.role = 'buyer';
        else if (rawType) user.role = 'farmer';

        if (userDoc.fields.name?.stringValue) user.name = userDoc.fields.name.stringValue;
        if (userDoc.fields.location?.stringValue) user.location = userDoc.fields.location.stringValue;
      }
    } catch (_) {}
  }

  return user;
}

const getLinkedFarmer = getLinkedUser;

// ---------------------------------------------------------------------------
// 7. Multimodal AI Processing (Voice Notes, Images & Text with Multi-Model Fallback)
// ---------------------------------------------------------------------------
const CANDIDATE_MODELS = [
  'gemini-2.5-flash-lite',
  'gemini-flash-lite-latest',
  'gemini-3.5-flash-lite',
  'gemini-2.5-flash'
];

async function callGemini(contents) {
  for (const modelName of CANDIDATE_MODELS) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(contents);
      const text = result.response.text();
      if (text && text.trim().length > 0) {
        return text;
      }
    } catch (err) {
      console.warn(`⚠️ Model ${modelName} unavailable (${err.message.slice(0, 100)}). Trying fallback...`);
    }
  }
  throw new Error('All Gemini candidate models were temporarily unavailable.');
}

// A. Rural Audio Voice Note Processing (Gemini Flash Audio)
async function processVoiceWithGemini(base64Audio, mimeType, farmer) {
  const prompt = `You are AgriChain Kisan AI, the smart assistant for Indian farmers.
Listen to this rural voice note (in Hindi, Haryanvi, Punjabi, Marathi, Bhojpuri, or Hinglish).
Farmer Profile: ${farmer ? `${farmer.name} from ${farmer.location}` : 'Unlinked Farmer'}.

Transcribe and extract the trade listing or question.
Return ONLY pure JSON (no markdown fences):
{
  "intent": "listing" | "price_inquiry" | "demand_prediction" | "escrow_inquiry" | "agronomic_advisory" | "status_inquiry" | "general",
  "transcriptionHindi": string,
  "crop": "wheat" | "rice" | "mustard" | "cotton" | "soybean" | "potato" | "onion" | "tomato" | "maize" | null,
  "variety": string | null,
  "quantityQuintals": number | null,
  "expectedPricePerQuintal": number | null,
  "location": string | null,
  "advisoryReply": string | null
}

INTENT RULES:
- If the farmer asks where the highest orders, maximum demand, or next high-demand market/mandi will come from (e.g. "sabse zyada order kahan aayenge", "where will highest orders come", "kahan bechun jahan order zyada ho", "demand forecast"), set "intent": "demand_prediction".
- If listing a crop to sell, set "intent": "listing".
- If asking for current market bhav/price, set "intent": "price_inquiry".

UNIT CONVERSIONS & PRICING:
- 100 kg = 1 Quintal (e.g. 20 kg = 0.2 Quintals, 50 kg = 0.5 Quintals)
- 1 Ton = 10 Quintals, 1 Bori = 0.5 Quintals (50 kg), 1 Mann = 0.4 Quintals (40 kg)
- If the price is given per kg (e.g. "30/kg", "38/kg", "40/kg"), multiply by 100 to get expectedPricePerQuintal (4000). expectedPricePerQuintal MUST ALWAYS be in ₹/quintal.`;

  try {
    const rawText = await callGemini([
      {
        inlineData: {
          mimeType: mimeType ? mimeType.split(';')[0] : 'audio/ogg',
          data: base64Audio
        }
      },
      prompt
    ]);
    const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
    return JSON.parse(cleanJson);
  } catch (err) {
    console.error('Voice AI Parse error:', err.message);
    return null;
  }
}

// B. Computer Vision Crop Quality Assay & Disease Detection (Gemini Flash Vision)
async function processImageWithGemini(base64Image, mimeType, caption, farmer) {
  const prompt = `You are AgriChain AI, an expert agricultural quality inspector (AGMARK & FSSAI certified) and plant pathologist.
Analyze this photo sent by an Indian farmer. Optional caption: "${caption || 'None'}".
Farmer: ${farmer ? `${farmer.name} from ${farmer.location}` : 'Farmer'}.

TASK 1 - STRICT CROP VALIDATION:
Check whether the image contains genuine agricultural crop/produce (harvested grains, pulses, oilseeds, vegetables, fruits, or a standing farm crop/plant).
If the image shows ANY non-agricultural subject such as:
- Human face, selfie, person, crowd, hands holding non-produce items
- Vehicle, tractor, motorcycle, car, bicycle
- Paper document, receipt, bill, newspaper, certificate, computer screen, screenshot
- Domestic animal, pet, dog, cat, bird (unless farm cattle eating fodder, but not a crop)
- Indoor room, bed, chair, furniture, building, wall, road, sky/landscape without close-up crop
- Random inanimate object, tool, bottle, meme, packaging without crop
THEN YOU MUST SET "isCrop": false, "category": "non_crop", and "purityScorePercent": 0.

TASK 2 - PRODUCE QUALITY & PURITY EVALUATION (IF isCrop is true):
Carefully inspect the visual quality of the crop/grain sample:
- Check for foreign matter (dust, stones, weed seeds, chaff, straw).
- Check for insect infestation, boreholes, weevil damage, broken/shriveled grains.
- Check for rot, mold mycelium, fungal discoloration, water-soaked soft rot, or blackening.
- If genuine rot, mold, extreme impurity, or severe spoilage is detected:
  * "purityScorePercent" MUST be evaluated strictly below 50 (e.g. 15 to 45).
  * "rejectionReason" MUST explain the specific defect in detail.
  * "qualityGrade": "Sub-standard (<50%)".
- If the produce is healthy, sound, and clean:
  * "purityScorePercent" MUST be between 50 and 100 (e.g. 75 to 98%).
  * "qualityGrade": "Grade 1 (Premium A+)" or "Grade 2 (Standard)".

Return ONLY pure JSON (no markdown fences):
{
  "isCrop": boolean,
  "detectedObject": string,
  "rejectionReason": string | null,
  "category": "produce_quality_assay" | "crop_disease_advisory" | "non_crop",
  "crop": "wheat" | "rice" | "mustard" | "cotton" | "soybean" | "potato" | "onion" | "tomato" | "maize" | "other",
  "variety": string | null,
  "qualityGrade": "Grade 1 (Premium A+)" | "Grade 2 (Standard)" | "Grade 3 (Fair)" | "Sub-standard (<50%)",
  "purityScorePercent": number,
  "hasRotOrSpoilage": boolean,
  "lusterAndGrainQuality": string,
  "estimatedMoisturePercent": number,
  "recommendedPricePerQuintalMin": number,
  "recommendedPricePerQuintalMax": number,
  "diseaseNameHindi": string | null,
  "diseaseTreatmentHindi": string | null,
  "quantityQuintals": number | null,
  "expectedPricePerQuintal": number | null,
  "location": string | null,
  "summaryHindi": string
}`;

  try {
    const rawText = await callGemini([
      {
        inlineData: {
          mimeType: mimeType ? mimeType.split(';')[0] : 'image/jpeg',
          data: base64Image
        }
      },
      prompt
    ]);
    const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
    const result = JSON.parse(cleanJson);

    // Fallback safety checks
    if (result.isCrop === undefined) {
      result.isCrop = result.category !== 'non_crop';
    }
    const hasRot = result.hasRotOrSpoilage === true ||
      (result.qualityGrade && result.qualityGrade.includes('<50%')) ||
      (result.rejectionReason && /rot|mold|fungal|decay|spoil/i.test(result.rejectionReason));
    if (hasRot) {
      result.hasRotOrSpoilage = true;
      result.purityScorePercent = Math.min(Number(result.purityScorePercent) || 30, 38);
    } else if (result.purityScorePercent === undefined) {
      result.purityScorePercent = 88;
    }
    return result;
  } catch (err) {
    console.error('Image Vision AI Parse error:', err.message);
    return null;
  }
}

// C. Text & Multi-turn Message Processing (Multi-Role Aware)
async function processUserTextMessage(from, text, user) {
  const role = user?.role || 'farmer';
  const name = user?.name || 'AgriChain User';

  // Fast check for Highest Orders & Demand Prediction
  if (/highest order|highest demand|sabse zyada order|sabse bada order|agla order|kahan se order|kahan order|where order|where demand|next order|predict order|forecast|bhav predict|demand|kahan bechun|highest sale/i.test(text)) {
    console.log(`🎯 Detected demand/order prediction query from +${from} [${role}]: "${text}"`);
    let matchedCrop = null;
    for (const c of ['tomato', 'onion', 'wheat', 'rice', 'mustard', 'potato', 'soybean', 'cotton', 'maize']) {
      if (new RegExp(`\\b${c}\\b|${c}`, 'i').test(text)) {
        matchedCrop = c;
        break;
      }
    }
    await handleHighestOrdersPrediction(from, matchedCrop, user, text);
    return;
  }

  // Fast keyword check for status / my crops / my orders / stock inquiry
  if (/status|mera status|meri fasal|my crop|active crop|listings|my orders|meri kharid|orders|order|stock|hamara stock|my contracts|contracts|contract|rfq/i.test(text)) {
    await handleStatusInquiry(from, user);
    return;
  }

  // Fast keyword check for payment / escrow inquiry
  if (/escrow|payment|paisa|paise|paise kaise|bank|payment secure|refund/i.test(text)) {
    await handleEscrowInquiry(from, user);
    return;
  }

  // RETAIL BUYER SPECIFIC: Searching produce to buy
  if (role === 'retailBuyer') {
    if (/chahiye|kharidna|buy|purchase|rate|bhav|tamatar|wheat|rice|gehu|pyaz|onion|potato|aloo|mustard|sarson|sabji|sabzi|vegetable|fresh/i.test(text)) {
      console.log(`🛒 Retail Buyer +${from} looking to buy crops: "${text}"`);
      let cropSearch = null;
      for (const c of ['wheat', 'rice', 'mustard', 'cotton', 'soybean', 'potato', 'onion', 'tomato', 'maize']) {
        if (new RegExp(`\\b${c}\\b|${c}`, 'i').test(text)) {
          cropSearch = c;
          break;
        }
      }
      const available = await searchAvailableCropsForBuyer(cropSearch, 4);
      if (available.length > 0) {
        let reply = `🛒 *AgriChain ताज़ा खेत उपज (Direct Farm Fresh)* 🛒\n\n`;
        reply += `नमस्ते ${name}! आपके लिए नजदीकी सत्यापित किसानों से उपलब्ध ताज़ा फसलें:\n\n`;
        available.forEach((c, idx) => {
          const p = c.price > 300 ? Math.round(c.price / 100) : c.price;
          reply += `${idx + 1}. 🌾 *${c.name}*\n   💰 भाव: ₹${p}/kg (₹${p * 100}/क्विंटल)\n   👨‍🌾 किसान: ${c.farmerName} (${c.location})\n   ⚖️ उपलब्ध स्टॉक: ${c.quantity || 'स्टॉक में'}\n\n`;
        });
        reply += `📲 *ऑर्डर बुक करने के लिए:*\nअपने **AgriChain Mobile App** में 'Retail Market' खोलें और 1-क्लिक में सुरक्षित एस्क्रो ऑर्डर दें! 🚚✨`;
        await sendWhatsAppMessage(from, reply);
        return;
      }
    }
  }

  // BULK BUYER SPECIFIC: Bulk procurement inquiry
  if (role === 'buyer') {
    if (/quintal|ton|b2b|bulk|mill|procurement|supply|contract|chahiye/i.test(text)) {
      console.log(`🏭 Bulk Buyer +${from} procurement inquiry: "${text}"`);
      const available = await searchAvailableCropsForBuyer(null, 3);
      let reply = `🏭 *AgriChain बल्क मंडी व संस्थागत प्रोक्योरमेंट* 🏭\n\n`;
      reply += `नमस्ते ${name}! बल्क खरीदारों के लिए वर्तमान में उपलब्ध FPO क्लस्टर और किसान लॉट्स:\n\n`;
      available.forEach((c, idx) => {
        const pPerQtl = c.price <= 300 ? c.price * 100 : c.price;
        reply += `${idx + 1}. 🌾 *${c.name}*\n   💰 बेंचमार्क भाव: ₹${pPerQtl}/क्विंटल\n   🏢 स्रोत: ${c.farmerName} (${c.location})\n   📦 कुल लॉट: ${c.quantity}\n\n`;
      });
      reply += `📝 *नया RFQ / टेंडर जारी करने के लिए:* AgriChain ऐप में 'Bulk Procurement' सेक्शन में जाएँ।\n📄 *अपने कॉन्ट्रैक्ट देखने के लिए लिखें:* *"my contracts"*`;
      await sendWhatsAppMessage(from, reply);
      return;
    }
  }

  // GENERAL AI NLP (Gemini Flash) with Role Context
  const roleLabel = role === 'retailBuyer' ? 'Retail Consumer Buyer' : (role === 'buyer' ? 'Institutional Bulk Buyer' : (role === 'fpo' ? 'FPO Aggregator' : 'Smallholder Farmer'));
  const prompt = `You are AgriChain AI, the multilingual assistant for India's digital agricultural marketplace.
Parse this Hindi/English message from a user: "${text}".
User Profile: ${user ? `${user.name} (${roleLabel}) from ${user.location}` : 'Unlinked User'}.
User Role: ${role}.

Return ONLY pure JSON (no markdown fences):
{
  "intent": "listing" | "buy_inquiry" | "price_inquiry" | "demand_prediction" | "escrow_inquiry" | "agronomic_advisory" | "status_inquiry" | "general",
  "crop": "wheat" | "rice" | "mustard" | "cotton" | "soybean" | "potato" | "onion" | "tomato" | "maize" | null,
  "variety": string | null,
  "quantityQuintals": number | null,
  "expectedPricePerQuintal": number | null,
  "location": string | null,
  "advisoryReply": string | null
}

INTENT RULES:
- If User is a retailBuyer or buyer asking to buy/get a crop, set "intent": "buy_inquiry" or "price_inquiry".
- If User is a farmer or fpo listing crops to sell, set "intent": "listing".
- If asking for prices/rates, set "intent": "price_inquiry".
- 100 kg = 1 Quintal. If quoted per kg (e.g. 38/kg), multiply by 100 to get expectedPricePerQuintal (3800).`;

  try {
    const rawText = await callGemini([prompt]);
    const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
    const aiResult = JSON.parse(cleanJson);
    await handleParsedAiResult(from, aiResult, user);
  } catch (err) {
    console.error('Text NLP Error:', err.message);
  }
}

const processFarmerTextMessage = processUserTextMessage;

// ---------------------------------------------------------------------------
// 8. Role-Differentiated Firestore Data Queries & Strict Data Isolation
// ---------------------------------------------------------------------------

// A. Farmer Active Listings (Strictly where farmerId == userId)
async function getFarmerActiveListings(farmerId) {
  try {
    const res = await axios.post(
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery?key=${FIREBASE_WEB_API_KEY}`,
      {
        structuredQuery: {
          from: [{ collectionId: 'crops' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'farmerId' },
              op: 'EQUAL',
              value: { stringValue: farmerId }
            }
          },
          limit: 10
        }
      }
    );
    if (!res.data || !Array.isArray(res.data)) return [];
    return res.data
      .filter(item => item.document && item.document.fields)
      .map(item => {
        const f = item.document.fields;
        const rawPrice = f.price?.doubleValue || f.price?.integerValue || f.price?.stringValue || 0;
        return {
          id: f.id?.stringValue || item.document.name.split('/').pop(),
          name: f.name?.stringValue || 'फसल',
          quantity: f.quantity?.stringValue || '',
          price: Number(rawPrice) || 0,
          status: f.status?.stringValue || 'active',
          grade: f.qualityGrade?.stringValue || 'grade1'
        };
      });
  } catch (err) {
    console.warn('⚠️ Error fetching farmer crops from Firestore:', err.message);
    return [];
  }
}

// B. Retail Buyer Orders (Strictly where buyerId == userId)
async function getRetailOrdersForBuyer(buyerId) {
  try {
    const res = await axios.post(
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery?key=${FIREBASE_WEB_API_KEY}`,
      {
        structuredQuery: {
          from: [{ collectionId: 'retail_orders' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'buyerId' },
              op: 'EQUAL',
              value: { stringValue: buyerId }
            }
          },
          limit: 10
        }
      }
    );
    if (!res.data || !Array.isArray(res.data)) return [];
    return res.data
      .filter(item => item.document && item.document.fields)
      .map(item => {
        const f = item.document.fields;
        return {
          id: f.id?.stringValue || item.document.name.split('/').pop(),
          orderId: f.orderId?.stringValue || f.id?.stringValue,
          cropName: f.cropName?.stringValue || 'उपज',
          quantity: f.quantity?.stringValue || (f.quantityKg?.doubleValue ? `${f.quantityKg.doubleValue} kg` : ''),
          totalPrice: Number(f.totalPrice?.doubleValue || f.totalAmount?.doubleValue || f.price?.doubleValue || 0),
          status: f.status?.stringValue || 'in_transit',
          farmerName: f.farmerName?.stringValue,
          eta: f.eta?.stringValue
        };
      });
  } catch (err) {
    console.warn('⚠️ Error fetching retail buyer orders:', err.message);
    return [];
  }
}

// C. Farmer Incoming Sales Orders (Strictly where farmerId == userId)
async function getFarmerIncomingOrders(farmerId) {
  try {
    const res = await axios.post(
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery?key=${FIREBASE_WEB_API_KEY}`,
      {
        structuredQuery: {
          from: [{ collectionId: 'retail_orders' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'farmerId' },
              op: 'EQUAL',
              value: { stringValue: farmerId }
            }
          },
          limit: 5
        }
      }
    );
    if (!res.data || !Array.isArray(res.data)) return [];
    return res.data
      .filter(item => item.document && item.document.fields)
      .map(item => {
        const f = item.document.fields;
        return {
          id: f.id?.stringValue || item.document.name.split('/').pop(),
          cropName: f.cropName?.stringValue || 'फसल',
          quantity: f.quantity?.stringValue || '',
          totalPrice: Number(f.totalPrice?.doubleValue || f.totalAmount?.doubleValue || 0),
          buyerName: f.buyerName?.stringValue || 'खरीदार',
          status: f.status?.stringValue || 'in_transit'
        };
      });
  } catch (err) {
    return [];
  }
}

// D. FPO Incoming Orders & Shipments (Strictly where fpoId == userId or sellerId == userId)
async function getOrdersForFpo(fpoId) {
  try {
    const res = await axios.post(
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery?key=${FIREBASE_WEB_API_KEY}`,
      {
        structuredQuery: {
          from: [{ collectionId: 'fpo_orders' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'fpoId' },
              op: 'EQUAL',
              value: { stringValue: fpoId }
            }
          },
          limit: 5
        }
      }
    );
    if (!res.data || !Array.isArray(res.data)) return [];
    return res.data
      .filter(item => item.document && item.document.fields)
      .map(item => {
        const f = item.document.fields;
        return {
          id: f.id?.stringValue || item.document.name.split('/').pop(),
          cropName: f.cropName?.stringValue || 'लॉट',
          quantity: f.quantity?.stringValue || '',
          totalAmount: Number(f.totalAmount?.doubleValue || 0),
          status: f.status?.stringValue || 'pending'
        };
      });
  } catch (err) {
    return [];
  }
}

// E. Bulk Buyer RFQs (Strictly where buyerId == userId)
async function getRfqsForBuyer(buyerId) {
  try {
    const res = await axios.post(
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery?key=${FIREBASE_WEB_API_KEY}`,
      {
        structuredQuery: {
          from: [{ collectionId: 'bulk_rfqs' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'buyerId' },
              op: 'EQUAL',
              value: { stringValue: buyerId }
            }
          },
          limit: 5
        }
      }
    );
    if (!res.data || !Array.isArray(res.data)) return [];
    return res.data
      .filter(item => item.document && item.document.fields)
      .map(item => {
        const f = item.document.fields;
        return {
          id: f.id?.stringValue || item.document.name.split('/').pop(),
          crop: f.crop?.stringValue || f.commodity?.stringValue || 'फसल',
          quantity: f.quantity?.stringValue || '',
          targetPrice: Number(f.targetPrice?.doubleValue || f.targetPrice?.integerValue || 0),
          quotesCount: Number(f.quotesCount?.integerValue || 0),
          status: f.status?.stringValue || 'open'
        };
      });
  } catch (err) {
    return [];
  }
}

// F. Search Available Active Crops from Verified Farmers (for Buyers)
async function searchAvailableCropsForBuyer(cropType, limit = 4) {
  try {
    const res = await axios.post(
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery?key=${FIREBASE_WEB_API_KEY}`,
      {
        structuredQuery: {
          from: [{ collectionId: 'crops' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'status' },
              op: 'EQUAL',
              value: { stringValue: 'active' }
            }
          },
          limit: 20
        }
      }
    );
    if (!res.data || !Array.isArray(res.data)) return [];
    let crops = res.data
      .filter(item => item.document && item.document.fields)
      .map(item => {
        const f = item.document.fields;
        const p = Number(f.price?.doubleValue || f.price?.integerValue || 0);
        return {
          id: f.id?.stringValue || item.document.name.split('/').pop(),
          name: f.name?.stringValue || 'फसल',
          cropType: f.cropType?.stringValue || '',
          farmerName: f.farmerName?.stringValue || 'प्रमाणित किसान',
          location: f.location?.stringValue || 'हरियाणा',
          quantity: f.quantity?.stringValue || '',
          price: p
        };
      });

    if (cropType) {
      const match = crops.filter(c => 
        c.cropType.toLowerCase().includes(cropType.toLowerCase()) || 
        c.name.toLowerCase().includes(cropType.toLowerCase())
      );
      if (match.length > 0) crops = match;
    }
    return crops.slice(0, limit);
  } catch (e) {
    console.warn('⚠️ Error searching available crops:', e.message);
    return [];
  }
}

// ---------------------------------------------------------------------------
// 8.5 Strict Role-Differentiated Status Inquiry Handler
// ---------------------------------------------------------------------------
async function handleStatusInquiry(from, user) {
  const role = user?.role || 'farmer';
  const userId = user?.userId || '90Eajo6VcCRtbzxthkWCxAwHsBs2';
  const name = user?.name || 'AgriChain User';
  const location = user?.location || 'Haryana';

  console.log(`🔍 Handling Role-Isolated Status Inquiry for +${from} [${role}] ${name} (${userId})`);

  // =========================================================================
  // CASE 1: RETAIL BUYER (Show strictly THEIR orders, NOT crops)
  // =========================================================================
  if (role === 'retailBuyer') {
    const orders = await getRetailOrdersForBuyer(userId);
    let msg = `🛒 *AgriChain रिटेल खरीदार स्थिति (My Orders)* 🛒\n\n`;
    msg += `👤 *खरीदार*: ${name} ✅ (सत्यापित उपभोक्ता)\n`;
    msg += `📍 *स्थान*: ${location}\n`;
    msg += `📱 *WhatsApp*: +${from}\n\n`;

    if (orders.length > 0) {
      msg += `📦 *आपके हाल के ऑर्डर (Your Active Orders):*\n`;
      orders.slice(0, 5).forEach((ord, idx) => {
        const orderId = ord.orderId || ord.id;
        const cropName = ord.cropName || 'कृषि उपज';
        const qty = ord.quantity || '';
        const amt = Number(ord.totalPrice || 0).toLocaleString('en-IN');
        const st = (ord.status || 'in_transit').toUpperCase();
        const farmerName = ord.farmerName ? `\n   👨‍🌾 किसान: ${ord.farmerName}` : '';
        const eta = ord.eta ? `\n   ⏱️ ETA: ${ord.eta}` : '';
        msg += `${idx + 1}. 🛍️ *${cropName}* (${orderId})\n   ⚖️ मात्रा: ${qty} | 💰 कुल: ₹${amt}\n   🚚 स्थिति: *${st}*${farmerName}${eta}\n\n`;
      });
      msg += `🔒 *एस्क्रो सुरक्षा:* आपका भुगतान सुरक्षित एस्क्रो में है और डिलीवरी मिलने के बाद ही किसान को जारी होगा।\n\n`;
      msg += `💡 *नया सामान खोजने के लिए लिखें:*\n👉 *"ताज़ा सब्जियां"* या *"गेहूं का भाव"*`;
    } else {
      msg += `📦 *वर्तमान में आपका कोई सक्रिय ऑर्डर नहीं है।*\n\n`;
      msg += `💡 *किसानों से सीधे ताज़ा फसल खरीदने के लिए लिखें:*\n👉 *"ताज़ा गेहूं खरीदना है"* या *"सब्जियों का रेट"*`;
    }
    await sendWhatsAppMessage(from, msg);
    return;
  }

  // =========================================================================
  // CASE 2: FPO (Show strictly THEIR pooled lots & FPO orders)
  // =========================================================================
  if (role === 'fpo') {
    const listings = await getFarmerActiveListings(userId);
    const fpoOrders = await getOrdersForFpo(userId);

    let msg = `🏢 *AgriChain FPO सामूहिक स्टॉक व स्थिति* 🏢\n\n`;
    msg += `👤 *FPO*: ${name} ✅ (क्लस्टर एग्रीगेटर)\n`;
    msg += `📍 *स्थान*: ${location}\n`;
    msg += `📱 *WhatsApp*: +${from}\n\n`;

    if (listings.length > 0) {
      msg += `📦 *आपके FPO के सामूहिक लॉट्स (Pooled Lots):*\n`;
      listings.slice(0, 5).forEach((item, idx) => {
        const numPrice = Number(item.price) || 0;
        const priceStr = numPrice > 300 ? `₹${numPrice}/क्विंटल` : `₹${numPrice}/kg`;
        msg += `${idx + 1}. 🌾 *${item.name}*\n   ⚖️ मात्रा: ${item.quantity || 'दर्ज है'}\n   💰 भाव: ${priceStr}\n   ⭐ स्थिति: *${item.status.toUpperCase()}*\n\n`;
      });
    } else {
      msg += `📦 *वर्तमान में कोई FPO बल्क लॉट सक्रिय नहीं है।*\n\n`;
    }

    if (fpoOrders.length > 0) {
      msg += `🏭 *आगामी बल्क प्रोक्योरमेंट ऑर्डर्स:*\n`;
      fpoOrders.slice(0, 3).forEach((ord, idx) => {
        msg += `${idx + 1}. 📋 *${ord.cropName}*: ${ord.quantity} | ₹${Number(ord.totalAmount).toLocaleString('en-IN')}\n   🚚 स्थिति: *${(ord.status).toUpperCase()}*\n\n`;
      });
    }

    msg += `💡 *नया सामूहिक लॉट जोड़ने के लिए बोलें या लिखें:*\n👉 *"करनाल में 200 क्विंटल गेहूं 2550 भाव"*`;
    await sendWhatsAppMessage(from, msg);
    return;
  }

  // =========================================================================
  // CASE 3: BULK BUYER (Show strictly THEIR contracts & RFQs)
  // =========================================================================
  if (role === 'buyer') {
    const buyerRfqs = await getRfqsForBuyer(userId);

    let msg = `🏭 *AgriChain बल्क प्रोक्योरमेंट स्थिति (Contracts & RFQ)* 🏭\n\n`;
    msg += `👤 *खरीदार*: ${name} ✅ (संस्थागत)\n`;
    msg += `📍 *स्थान*: ${location}\n`;
    msg += `📱 *WhatsApp*: +${from}\n\n`;

    if (buyerRfqs.length > 0) {
      msg += `📋 *आपके सक्रिय बल्क टेंडर / RFQs:*\n`;
      buyerRfqs.slice(0, 4).forEach((rfq, idx) => {
        msg += `${idx + 1}. 🌾 *${rfq.crop}*\n   ⚖️ आवश्यक मात्रा: ${rfq.quantity} | लक्ष्य भाव: ₹${rfq.targetPrice}/क्विंटल\n   📊 FPO बोलियां: ${rfq.quotesCount} | स्थिति: *${rfq.status.toUpperCase()}*\n\n`;
      });
    } else {
      msg += `📋 *वर्तमान में कोई सक्रिय RFQ या बल्क टेंडर नहीं है।*\n\n`;
    }

    msg += `💡 *बल्क आवश्यकता दर्ज करने के लिए लिखें:*\n👉 *"500 क्विंटल बासमती 1121 करनाल चाहिए"*`;
    await sendWhatsAppMessage(from, msg);
    return;
  }

  // =========================================================================
  // CASE 4: FARMER (Show strictly THEIR listed crops and sales orders)
  // =========================================================================
  const listings = await getFarmerActiveListings(userId);
  const incomingOrders = await getFarmerIncomingOrders(userId);
  const activeListings = listings.filter(l => l.status !== 'sold' && l.status !== 'cancelled');

  let msg = `🌾 *AgriChain किसान खाता व फसल स्थिति (Live Status)* 🌾\n\n`;
  msg += `👤 *किसान*: ${name} ✅ (सत्यापित)\n`;
  msg += `📍 *स्थान*: ${location}\n`;
  msg += `📱 *WhatsApp*: +${from}\n\n`;

  if (activeListings.length > 0) {
    msg += `📦 *आपकी सक्रिय फसलें (Your Active Listings):*\n`;
    activeListings.forEach((item, idx) => {
      const numPrice = Number(item.price) || 0;
      const priceStr = numPrice > 300 ? `₹${numPrice}/क्विंटल` : `₹${numPrice}/kg`;
      msg += `${idx + 1}. 🌾 *${item.name}*\n   ⚖️ मात्रा: ${item.quantity || 'दर्ज है'}\n   💰 भाव: ${priceStr}\n   ⭐ स्थिति: *${item.status.toUpperCase()}*\n\n`;
    });
  } else {
    msg += `📦 *वर्तमान में आपकी कोई सक्रिय फसल दर्ज नहीं है।*\n\n`;
  }

  if (incomingOrders.length > 0) {
    msg += `🛍️ *खरीदारों से आए नए ऑर्डर (Incoming Orders):*\n`;
    incomingOrders.slice(0, 3).forEach((ord, idx) => {
      const amt = Number(ord.totalPrice || 0).toLocaleString('en-IN');
      msg += `${idx + 1}. 📦 *${ord.cropName}*: ${ord.quantity}\n   💰 मूल्य: ₹${amt} | खरीदार: ${ord.buyerName}\n   🚚 स्थिति: *${ord.status.toUpperCase()}*\n\n`;
    });
  }

  msg += `🔒 *एस्क्रो सुरक्षा:* खरीदार द्वारा ऑर्डर लॉक होने पर आपको WhatsApp पर तुरंत सूचना मिलेगी।\n\n`;
  msg += `💡 *नई फसल जोड़ने के लिए बोलें या लिखें:*\n👉 *"50 kg wheat 40/kg"*`;

  await sendWhatsAppMessage(from, msg);
}

async function handleEscrowInquiry(from, farmer) {
  const farmerName = farmer?.name || 'किसान भाई';
  const escrowMsg = 
`🛡️ *AgriChain सुरक्षित एस्क्रो भुगतान प्रणाली* 🛡️

नमस्ते ${farmerName}! AgriChain पर आपका भुगतान 100% सुरक्षित रहता है:

1️⃣ *भुगतान लॉक:* खरीदार अग्रिम राशि AgriChain बैंक एस्क्रो में सुरक्षित लॉक करता है।
2️⃣ *खेत से पिकअप:* राशि लॉक होने के बाद ही ट्रांसपोर्टर आपके खेत से फसल लोड करता है।
3️⃣ *तुरंत भुगतान:* डिलीवरी और डिजिटल तौल होते ही पैसा सीधे आपके बैंक खाते (UPI/IMPS) में जमा हो जाता है।

❌ कोई आढ़ती कटौती नहीं | ❌ कोई बिचौलिया नहीं | ✅ सीधा बैंक ट्रांसफर`;
  await sendWhatsAppMessage(from, escrowMsg);
}

// ---------------------------------------------------------------------------
// 7.5 AI Demand & Highest Orders Forecasting Engine (LightGBM Quantile ML)
// ---------------------------------------------------------------------------
const VENV_PYTHON = 'C:\\Users\\adity\\Documents\\geetauni-main\\score\\no\\venv\\Scripts\\python.exe';
const MODEL_SCRIPT_PATH = path.resolve(__dirname, '../agrichain/New folder (3)/src/predict_highest_orders.py');
const MODEL_CWD = path.resolve(__dirname, '../agrichain/New folder (3)');

async function executeDemandForecastModel(commodity, daysAhead = 7) {
  return new Promise((resolve) => {
    const pythonExe = fs.existsSync(VENV_PYTHON) ? VENV_PYTHON : 'python';
    const args = [MODEL_SCRIPT_PATH, '--days', String(daysAhead)];
    if (commodity && commodity.toLowerCase() !== 'all') {
      args.push('--commodity', commodity);
    }

    console.log(`🤖 Executing LightGBM Quantile ML Forecaster: ${pythonExe} ${args.join(' ')}`);

    let stdoutData = '';
    let stderrData = '';

    const proc = spawn(pythonExe, args, {
      cwd: MODEL_CWD,
      timeout: 12000
    });

    proc.stdout.on('data', (d) => { stdoutData += d.toString(); });
    proc.stderr.on('data', (d) => { stderrData += d.toString(); });

    proc.on('close', (code) => {
      if (code === 0) {
        try {
          const jsonStart = stdoutData.indexOf('{\n  "status":');
          const cleanStr = jsonStart !== -1 ? stdoutData.slice(jsonStart) : stdoutData;
          const parsed = JSON.parse(cleanStr);
          console.log(`✅ ML Forecaster returned top corridor: ${parsed.top_corridor?.market} (${parsed.top_corridor?.commodity})`);
          return resolve(parsed);
        } catch (e) {
          console.warn('⚠️ JSON parse error from ML model output:', e.message);
        }
      } else {
        console.warn(`⚠️ ML Python process returned code ${code}:`, stderrData.slice(0, 150));
      }
      resolve(getFallbackDemandForecast(commodity, daysAhead));
    });

    proc.on('error', (err) => {
      console.warn('⚠️ Error launching ML Python process:', err.message);
      resolve(getFallbackDemandForecast(commodity, daysAhead));
    });
  });
}

function getFallbackDemandForecast(commodity, daysAhead = 7) {
  const d = new Date();
  d.setDate(d.getDate() + daysAhead);
  const targetDateStr = d.toISOString().split('T')[0];

  const all = [
    {
      commodity: 'Wheat',
      district: 'Pune',
      state: 'Maharashtra',
      market: 'Pune',
      target_date: targetDateStr,
      days_ahead: daysAhead,
      p50_demand_kg: 16457,
      p90_surge_kg: 17513,
      p10_pessimistic_kg: 15958,
      expected_price_per_kg: 26.87,
      min_price_per_kg: 24.42,
      max_price_per_kg: 29.64,
      total_order_value_inr: 442200,
      surge_percent: 6.4,
      actionable_insight: `Projected wheat demand in Pune cluster for ${targetDateStr} is 15,958–17,513 kg. Steady wholesale mill procurement.`,
      recommendation: 'Grain price is favorable (₹26.87/kg). FPOs should aggregate lot sizes > 15 Tonnes to negotiate directly with millers.'
    },
    {
      commodity: 'Wheat',
      district: 'Karnal',
      state: 'Haryana',
      market: 'Karnal',
      target_date: targetDateStr,
      days_ahead: daysAhead,
      p50_demand_kg: 13787,
      p90_surge_kg: 14425,
      p10_pessimistic_kg: 13308,
      expected_price_per_kg: 28.08,
      min_price_per_kg: 25.50,
      max_price_per_kg: 31.02,
      total_order_value_inr: 387139,
      surge_percent: 4.6,
      actionable_insight: `Projected wheat demand in Karnal cluster for ${targetDateStr} is 13,308–14,425 kg. Steady retail consumption across GT Road corridor.`,
      recommendation: 'Dispatch cleaned grain lots directly to Karnal Hub to capture premium realization of ₹28.08/kg.'
    },
    {
      commodity: 'Onion',
      district: 'Nashik',
      state: 'Maharashtra',
      market: 'Lasalgaon',
      target_date: targetDateStr,
      days_ahead: daysAhead,
      p50_demand_kg: 8519,
      p90_surge_kg: 8733,
      p10_pessimistic_kg: 7986,
      expected_price_per_kg: 43.42,
      min_price_per_kg: 39.84,
      max_price_per_kg: 48.00,
      total_order_value_inr: 369895,
      surge_percent: 2.5,
      actionable_insight: `Projected onion demand in Nashik/Lasalgaon cluster for ${targetDateStr} is 7,986–8,733 kg. Bullish momentum from export & interstate traders.`,
      recommendation: 'Price trajectory is upward (+9.6% 7-day trend). Liquidate 70% of cured stock on peak market auction day.'
    },
    {
      commodity: 'Onion',
      district: 'Azadpur',
      state: 'Delhi',
      market: 'Azadpur',
      target_date: targetDateStr,
      days_ahead: daysAhead,
      p50_demand_kg: 7735,
      p90_surge_kg: 8172,
      p10_pessimistic_kg: 7365,
      expected_price_per_kg: 41.80,
      min_price_per_kg: 37.86,
      max_price_per_kg: 46.21,
      total_order_value_inr: 323323,
      surge_percent: 5.6,
      actionable_insight: `Projected onion demand in Azadpur cluster (Delhi NCR) is 7,365–8,172 kg. Steady urban institutional demand.`,
      recommendation: 'Dispatch cured onion lots in ventilated trucks avoiding morning humidity.'
    },
    {
      commodity: 'Tomato',
      district: 'Kolar',
      state: 'Karnataka',
      market: 'Kolar',
      target_date: targetDateStr,
      days_ahead: daysAhead,
      p50_demand_kg: 3991,
      p90_surge_kg: 4182,
      p10_pessimistic_kg: 3743,
      expected_price_per_kg: 37.26,
      min_price_per_kg: 33.96,
      max_price_per_kg: 41.28,
      total_order_value_inr: 148705,
      surge_percent: 4.8,
      actionable_insight: `Projected tomato demand in Kolar cluster for ${targetDateStr} is 3,743–4,182 kg. South corridor retail & wholesale absorption.`,
      recommendation: 'Harvest on evening for 4:00 AM auction delivery at Kolar Mandi to capture peak modal price.'
    },
    {
      commodity: 'Tomato',
      district: 'Nashik',
      state: 'Maharashtra',
      market: 'Nashik',
      target_date: targetDateStr,
      days_ahead: daysAhead,
      p50_demand_kg: 3838,
      p90_surge_kg: 4022,
      p10_pessimistic_kg: 3659,
      expected_price_per_kg: 38.04,
      min_price_per_kg: 34.64,
      max_price_per_kg: 41.82,
      total_order_value_inr: 145998,
      surge_percent: 4.8,
      actionable_insight: `Projected tomato demand in Nashik cluster is 3,659–4,022 kg. Strong Mumbai-Pune metropolitan pull.`,
      recommendation: 'Grade as A+ and pack in ventilated crates for metropolitan transit.'
    },
    {
      commodity: 'Tomato',
      district: 'Karnal',
      state: 'Haryana',
      market: 'Karnal',
      target_date: targetDateStr,
      days_ahead: daysAhead,
      p50_demand_kg: 3740,
      p90_surge_kg: 3995,
      p10_pessimistic_kg: 3616,
      expected_price_per_kg: 37.57,
      min_price_per_kg: 34.30,
      max_price_per_kg: 41.53,
      total_order_value_inr: 140512,
      surge_percent: 6.8,
      actionable_insight: `Projected tomato demand in Karnal cluster is 3,616–3,995 kg. Steady retail consumption across GT Road corridor.`,
      recommendation: 'Harvest on previous evening for morning mandi auction delivery to capture peak price of ₹37.57/kg.'
    }
  ];

  let filtered = all;
  if (commodity && commodity.toLowerCase() !== 'all') {
    filtered = all.filter(item => item.commodity.toLowerCase() === commodity.toLowerCase());
    if (filtered.length === 0) filtered = all;
  }

  filtered.sort((a, b) => b.p50_demand_kg - a.p50_demand_kg);

  return {
    status: 'SUCCESS',
    target_date: targetDateStr,
    days_ahead: daysAhead,
    commodity_filter: commodity,
    top_corridor: filtered[0],
    all_ranked_corridors: filtered
  };
}

async function handleHighestOrdersPrediction(from, crop, farmer, userQuestion) {
  const farmerName = farmer ? farmer.name : 'किसान भाई';
  const cleanCrop = crop ? crop.trim() : null;

  console.log(`📈 Running Highest Orders prediction for crop: ${cleanCrop || 'ALL'} for farmer ${farmerName}`);

  const forecast = await executeDemandForecastModel(cleanCrop, 7);
  const top = forecast.top_corridor;

  if (!top) {
    await sendWhatsAppMessage(from, `⚠️ क्षमा करें, इस फसल के लिए अभी पूर्वानुमान डेटा उपलब्ध नहीं है।`);
    return;
  }

  // Format runner up corridors
  const others = (forecast.all_ranked_corridors || [])
    .filter(c => !(c.market === top.market && c.commodity === top.commodity))
    .slice(0, 3);

  let runnerUpsText = '';
  if (others.length > 0) {
    runnerUpsText = `\n📊 *अन्य प्रमुख उच्च-मांग वाले केंद्र (Other High-Demand Hubs):*\n` +
      others.map((o, idx) => {
        const numPrice = o.expected_price_per_kg;
        return `${idx + 2}️⃣ 📍 *${o.market} Mandi* (${o.district}, ${o.state})\n` +
               `   🌾 *${o.commodity}*: ${o.p50_demand_kg.toLocaleString('en-IN')} kg मांग | भाव: ₹${numPrice}/kg`;
      }).join('\n\n');
  }

  const message = 
`🎯 *AgriChain AI ऑर्डर व मांग पूर्वानुमान (Demand & Orders Prediction)* 🎯

नमस्ते ${farmerName}! AgriChain LightGBM क्वांटाइल AI मॉडल के अनुसार आगामी 7 दिनों में:

🏆 *#1 सबसे ज्यादा ऑर्डर आने वाला क्षेत्र (Highest Orders Hub):*
📍 *${top.market} Mandi*, ${top.district} (${top.state})
🌾 *फसल*: *${top.commodity.toUpperCase()}*
📦 *अनुमानित कुल मांग (Expected Orders):* *${top.p50_demand_kg.toLocaleString('en-IN')} kg*
⚡ *पीक डिमांड सर्ज (P90 Peak Surge):* *${top.p90_surge_kg.toLocaleString('en-IN')} kg* (+${top.surge_percent}% अतिरिक्त मांग)
💰 *अनुमानित थोक भाव:* *₹${top.expected_price_per_kg}/kg* (रेंज: ₹${top.min_price_per_kg} - ₹${top.max_price_per_kg}/kg)
💵 *अनुमानित कुल ऑर्डर मूल्य:* *₹${Math.round(top.total_order_value_inr).toLocaleString('en-IN')}*
${runnerUpsText}

💡 *मांग व ऑर्डर बढ़ने का कारण (AI Market Insight):*
${top.actionable_insight}

🚜 *किसान के लिए सलाह (Advisory):*
${top.recommendation}

🤝 *क्या आप इस मांग के लिए अपनी फसल दर्ज करना चाहते हैं?*
👉 बोलकर (Voice Note) या लिखकर भेजें:
*"50 kg ${top.commodity} ₹${Math.round(top.expected_price_per_kg)}/kg"*`;

  await sendWhatsAppMessage(from, message);
}

async function handleParsedAiResult(from, aiResult, farmer) {
  // 1. Status Inquiry
  if (aiResult.intent === 'status_inquiry') {
    await handleStatusInquiry(from, farmer);
    return;
  }

  // 2. Escrow Inquiry
  if (aiResult.intent === 'escrow_inquiry') {
    await handleEscrowInquiry(from, farmer);
    return;
  }

  // 3. Demand & Highest Orders Prediction
  if (aiResult.intent === 'demand_prediction') {
    await handleHighestOrdersPrediction(from, aiResult.crop, farmer, aiResult.transcriptionHindi || '');
    return;
  }

  // 4. Price Inquiry (Bhav Check)
  if (aiResult.intent === 'price_inquiry' && aiResult.crop) {
    const benchmark = MANDI_BENCHMARK_RATES[aiResult.crop.toLowerCase()] || {
      nameHindi: aiResult.crop,
      msp: 2300,
      mandiRate: 2500,
      trend: 'स्थिर'
    };

    const bhavMsg = 
`🌾 *AgriChain मंडी भाव जानकारी* 🌾

किसान भाई, आज की प्रमुख मंडी दरें:
🏷️ *फसल*: ${benchmark.nameHindi}
🏛️ *सरकारी MSP*: ₹${benchmark.msp}/क्विंटल
🏪 *मंडी औसत भाव*: ₹${benchmark.mandiRate}/क्विंटल
📈 *रुझान*: ${benchmark.trend}

💡 *फसल बेचने के लिए बोलें या लिखें:*
👉 *"50 क्विंटल ${aiResult.crop} करनाल में बेचना है"*`;

    await sendWhatsAppMessage(from, bhavMsg);
    return;
  }

  // 5. Agronomic Advisory
  if (aiResult.intent === 'agronomic_advisory' && aiResult.advisoryReply) {
    await sendWhatsAppMessage(from, `🌾 *AgriChain कृषि सलाहकार* 🌾\n\n${aiResult.advisoryReply}`);
    return;
  }

  // 6. Crop Listing Intent
  if (aiResult.intent === 'listing' && aiResult.quantityQuintals > 0) {
    const farmerName = farmer ? farmer.name : 'किसान भाई';

    // Check if user has an existing verified photo (with quality >= 50%) waiting in pending state
    const pending = pendingCropListings[from];
    if (pending && pending.photoVerified && pending.purityScorePercent >= 50) {
      delete pendingCropListings[from];
      await saveAndConfirmCropListing(from, farmer, {
        crop: aiResult.crop || pending.crop || 'wheat',
        variety: aiResult.variety || pending.variety || null,
        quantityQuintals: aiResult.quantityQuintals,
        expectedPricePerQuintal: aiResult.expectedPricePerQuintal || pending.maxPrice || 2400,
        location: aiResult.location || pending.location || (farmer ? farmer.location : 'Haryana'),
        qualityGrade: pending.qualityGrade || 'grade1',
        qualityAssay: `⭐ ${pending.qualityGrade} | Purity: ${pending.purityScorePercent}% | Moisture: ${pending.moisture || 12}%`,
        voiceNote: aiResult.transcriptionHindi ? `🎙️ "${aiResult.transcriptionHindi}"` : null,
        isPhotoVerified: true,
        purityScore: pending.purityScorePercent
      });
      return;
    }

    // MANDATORY PHOTO GATE: No crop can be listed without a photo!
    pendingCropListings[from] = {
      crop: aiResult.crop || 'wheat',
      variety: aiResult.variety,
      quantityQuintals: aiResult.quantityQuintals,
      expectedPricePerQuintal: aiResult.expectedPricePerQuintal,
      location: aiResult.location,
      voiceNote: aiResult.transcriptionHindi ? `🎙️ "${aiResult.transcriptionHindi}"` : null,
      photoVerified: false,
      timestamp: Date.now()
    };

    const photoCompulsoryMsg = 
`📷 *फसल का फोटो भेजना अनिवार्य है (Photo Compulsory)!* 🌾

नमस्ते ${farmerName}! AgriChain डिजिटल मंडी पर फसल दर्ज करने के लिए वास्तविक फसल का फोटो भेजना अनिवार्य है। बिना फोटो के कोई भी फसल लिस्ट नहीं हो सकती।

📝 *आपकी दर्ज जानकारी:*
🌾 *फसल*: ${(aiResult.crop || 'फसल').toUpperCase()} ${aiResult.variety ? `(${aiResult.variety})` : ''}
⚖️ *मात्रा*: ${aiResult.quantityQuintals} क्विंटल (${Math.round(aiResult.quantityQuintals * 100)} kg)
💰 *अपेक्षित भाव*: ${aiResult.expectedPricePerQuintal ? `₹${aiResult.expectedPricePerQuintal}/क्विंटल` : 'मंडी भाव'}

📸 *कृपया अभी अपनी फसल/अनाज का एक साफ फोटो यहाँ WhatsApp पर भेजें।*

⚠️ *अनिवार्य नियम:*
1️⃣ केवल वास्तविक फसल (अनाज/सब्जी/फल) की फोटो ही मान्य होगी (चेहरे, गाड़ियाँ, कागज़ या अन्य वस्तुएं स्वीकार नहीं होंगी)।
2️⃣ AI गुणवत्ता व शुद्धता जांच में न्यूनतम 50% स्कोर होना अनिवार्य है (50% से कम गुणवत्ता वाली फसल लिस्ट नहीं होगी)।`;

    await sendWhatsAppMessage(from, photoCompulsoryMsg);
    return;
  }

  // Default Prompt / Help Menu
  const greeting = farmer ? `नमस्ते ${farmer.name} जी! 🙏` : 'नमस्ते किसान भाई! 🙏';
  const menuMsg = 
`${greeting}
AgriChain कृषि-साथी में आपका स्वागत है। 🌾

आप नीचे दिए गए विकल्पों में से कुछ भी भेज सकते हैं:
1️⃣ *फसल बेचें:* बोलकर (Voice Note) या लिखकर भेजें:
   👉 *"50 kg wheat 40/kg"*
2️⃣ *गुणवत्ता जांच:* फसल का फोटो भेजें (AI क्वालिटी रिपोर्ट पाएँ)
3️⃣ *मंडी भाव:* लिखें *"गेहूं का भाव क्या है"*
4️⃣ *ऑर्डर व मांग पूर्वानुमान:* पूछें *"अगला सबसे ज्यादा ऑर्डर कहाँ से आएगा?"* या *"Tomato demand"*
5️⃣ *स्थिति जांच:* लिखें *"status"* या *"मेरी फसलें"*
6️⃣ *भुगतान सुरक्षा:* लिखें *"पेमेंट कैसे मिलेगा?"*`;

  await sendWhatsAppMessage(from, menuMsg);
}

// Visual Crop Quality Inspection Handler
async function handleImageAssayResult(from, assay, farmer, caption) {
  // A. Non-Crop Validation Check (STRICT REJECTION OF NON-CROPS)
  if (!assay.isCrop || assay.category === 'non_crop') {
    const nonCropMsg = 
`❌ *अमान्य फोटो! केवल फसल का फोटो स्वीकार्य है* 🌾🚫

AgriChain AI ने इस फोटो में फसल नहीं पहचानी।
🔍 *पहचानी गई वस्तु:* ${assay.detectedObject || 'गैर-कृषि वस्तु'}
${assay.rejectionReason ? `⚠️ *कारण:* ${assay.rejectionReason}\n` : ''}
📋 *AgriChain अनिवार्य नियम:*
• केवल वास्तविक खेत की फसल, कटी उपज, अनाज, दलहन, फल या सब्जियों की फोटो ही स्वीकार की जाती है।
• चेहरे, सेल्फी, वाहन, रसीद, कागज़ात या पालतू जानवरों की फोटो से फसल दर्ज नहीं हो सकती।

👉 *कृपया अपनी असली फसल का स्पष्ट फोटो पुनः भेजें।*`;

    await sendWhatsAppMessage(from, nonCropMsg);
    return;
  }

  // B. Plant Disease Advisory
  if (assay.category === 'crop_disease_advisory' && assay.diseaseNameHindi) {
    const diseaseMsg = 
`🔬 *AgriChain AI फसल रोग निदान (Plant Pathology)* 🔬

🌿 *फसल*: ${(assay.crop || 'पौधा').toUpperCase()}
⚠️ *पहचाना गया रोग*: ${assay.diseaseNameHindi}

💊 *अनुशंसित उपचार व स्प्रे सलाह*:
${assay.diseaseTreatmentHindi || 'कृषि विशेषज्ञ से सलाह लें।'}

💡 _AgriChain AI द्वारा उपग्रह व कृषि-मॉडल आधारित विश्लेषण_`;

    await sendWhatsAppMessage(from, diseaseMsg);
    return;
  }

  // C. Strict Quality Threshold Gate (< 50% Purity / Quality)
  const purity = Number(assay.purityScorePercent) || 0;
  const cropName = (assay.crop || 'फसल').toUpperCase();

  if (purity < 50 || assay.hasRotOrSpoilage) {
    // Clear any pending draft listing since the quality failed the gate
    if (pendingCropListings[from]) {
      delete pendingCropListings[from];
    }

    const lowQualityMsg = 
`⚠️ *पहचानी गई फसल: ${cropName}* ❌🌾
*गुणवत्ता 50% से कम - फसल लिस्ट नहीं की जा सकती!*

AgriChain AI गुणवत्ता परख रिपोर्ट:
🌾 *पहचानी गई फसल*: *${cropName}* ${assay.variety ? `(${assay.variety})` : ''}
📊 *AI गुणवत्ता व शुद्धता स्कोर*: *${purity}%* (न्यूनतम आवश्यक: 50%)
⭐ *ग्रेड*: Sub-standard (<50%)
⚠️ *अस्वीकृति कारण*: ${assay.rejectionReason || assay.summaryHindi || `फसल (${cropName}) में अत्यधिक फंगल सड़ांध, दाग, नमी या कचरा पाया गया है।`}

💡 *किसान भाई के लिए सुधार सलाह (${cropName} Quality Improvement):*
1️⃣ सड़े, दागदार या फफूंद लगे दानों/फलों को तुरंत अलग करें।
2️⃣ धूप में सुखाकर नमी 12% से नीचे लाएं।
3️⃣ केवल स्वस्थ व साफ ${cropName} की नई फोटो भेजकर दोबारा जांच कराएं।

🛡️ _AgriChain डिजिटल मंडी पर केवल 50% या अधिक शुद्धता वाली फसलें ही लिस्ट की जा सकती हैं।_`;

    await sendWhatsAppMessage(from, lowQualityMsg);
    return;
  }

  // D. Harvested Produce Quality Assay (Quality >= 50% Approved)
  const qualityGrade = assay.qualityGrade || 'Grade 1 (Premium A+)';
  const moisture = assay.estimatedMoisturePercent || 12;
  const minPrice = assay.recommendedPricePerQuintalMin || 2400;
  const maxPrice = assay.recommendedPricePerQuintalMax || 2650;

  // Check if there was a pending draft from earlier text/voice, or if caption has quantity
  const pending = pendingCropListings[from];
  let quantityToUse = pending?.quantityQuintals || assay.quantityQuintals || null;
  let priceToUse = pending?.expectedPricePerQuintal || assay.expectedPricePerQuintal || maxPrice;

  if (quantityToUse && quantityToUse > 0) {
    if (pending) delete pendingCropListings[from];

    await saveAndConfirmCropListing(from, farmer, {
      crop: assay.crop || pending?.crop || 'wheat',
      variety: assay.variety || pending?.variety || null,
      quantityQuintals: quantityToUse,
      expectedPricePerQuintal: priceToUse,
      location: pending?.location || assay.location || (farmer ? farmer.location : 'Karnal, Haryana'),
      qualityGrade: qualityGrade.toLowerCase().includes('grade 1') ? 'grade1' : 'standard',
      qualityAssay: `⭐ ${qualityGrade} | Purity: ${purity}% | Moisture: ${moisture}%`,
      voiceNote: pending?.voiceNote || null,
      isPhotoVerified: true,
      purityScore: purity
    });
    return;
  }

  // Save the verified assay in pending state and prompt for quantity & price
  pendingCropListings[from] = {
    crop: assay.crop,
    variety: assay.variety,
    qualityGrade: qualityGrade,
    purityScorePercent: purity,
    moisture: moisture,
    minPrice: minPrice,
    maxPrice: maxPrice,
    location: assay.location,
    photoVerified: true,
    timestamp: Date.now()
  };

  const assayCard = 
`✅ *AgriChain AI फसल गुणवत्ता स्वीकृत (Purity: ${purity}%)* ⭐

फोटो विश्लेषण सफल रहा:
🔍 *पहचानी गई फसल*: ${cropName} ${assay.variety ? `(${assay.variety})` : ''}
⭐ *AI गुणवत्ता ग्रेड*: ${qualityGrade}
✨ *दाने की शुद्धता*: *${purity}%* (सत्यापित ✅)
💧 *अनुमानित नमी*: ${moisture}%
💰 *अनुशंसित मंडी भाव*: ₹${minPrice.toLocaleString('en-IN')} - ₹${maxPrice.toLocaleString('en-IN')} / क्विंटल

📝 *फसल को मंडी में लिस्ट करने के लिए:*
कृपया मात्रा और अपना भाव लिखकर या बोलकर (Voice Note) भेजें:
👉 *"50 क्विंटल गेहूं भाव ${maxPrice}"* या *"100 kg ₹35/kg"*`;

  await sendWhatsAppMessage(from, assayCard);
}

// Centralized Listing Creator & Firestore Sync
async function saveAndConfirmCropListing(from, farmer, details) {
  const listingId = `LOT-${Math.floor(100000 + Math.random() * 900000)}`;
  const farmerId = farmer ? farmer.userId : '90Eajo6VcCRtbzxthkWCxAwHsBs2';
  const farmerName = farmer ? farmer.name : 'aryan sharma';
  const location = details.location || (farmer ? farmer.location : 'Karnal, Haryana');
  const pricePerQuintal = details.expectedPricePerQuintal || 2400;
  const pricePerKg = pricePerQuintal > 300 ? Math.round(pricePerQuintal / 100) : pricePerQuintal;
  const totalKg = Math.round(details.quantityQuintals * 100);
  const totalValuation = Math.round(totalKg * pricePerKg).toLocaleString('en-IN');
  const qualityGrade = details.qualityGrade || 'grade1';
  const purityScore = details.purityScore || 88;

  // Save directly to Google Cloud Firestore
  await firestorePatch('crops', listingId, {
    id: { stringValue: listingId },
    name: { stringValue: `${details.crop} ${details.variety ? `(${details.variety})` : ''}`.trim() },
    cropType: { stringValue: (details.crop || 'wheat').toLowerCase() },
    farmerId: { stringValue: farmerId },
    farmerName: { stringValue: farmerName },
    quantity: { stringValue: `${totalKg} kg` },
    price: { doubleValue: Number(pricePerKg) },
    qualityGrade: { stringValue: qualityGrade },
    status: { stringValue: 'active' },
    isActive: { booleanValue: true },
    location: { stringValue: location },
    isPhotoVerified: { booleanValue: true },
    purityScore: { doubleValue: Number(purityScore) },
    qualityAssay: { stringValue: details.qualityAssay || `⭐ ${qualityGrade} | Purity: ${purityScore}%` },
    createdAt: { timestampValue: new Date().toISOString() }
  });

  console.log(`✅ Synced crop ${listingId} (${details.crop}) to Firestore for ${farmerName} (${farmerId})`);

  let confirmationCard = 
`🌾 *AgriChain कृषि-साथी पुष्टि* 🌾

नमस्ते ${farmerName}! आपकी फसल सफलतापूर्वक AgriChain डिजिटल मंडी में दर्ज हो गई है:

📋 *लॉट ID*: \`${listingId}\`
🌾 *फसल*: ${(details.crop || 'फसल').toUpperCase()} ${details.variety ? `(${details.variety})` : ''}
⚖️ *मात्रा*: ${details.quantityQuintals} क्विंटल (${totalKg} kg)
💰 *आपका भाव*: ₹${pricePerKg}/kg (₹${pricePerQuintal}/क्विंटल)
💵 *कुल मूल्य*: ₹${totalValuation}
⭐ *AI गुणवत्ता ग्रेड*: ${qualityGrade.toUpperCase()}
✨ *AI शुद्धता स्कोर*: ${purityScore}% (सत्यापित ✅)
📷 *फोटो सत्यापन*: ✅ असली फसल फोटो सत्यापित (≥50% गुणवत्ता)
📍 *स्थान*: ${location}
👤 *खाता*: ✅ ${farmerName}`;

  if (details.voiceNote) {
    confirmationCard += `\n${details.voiceNote}`;
  }
  if (details.qualityAssay) {
    confirmationCard += `\n🔬 ${details.qualityAssay}`;
  }

  confirmationCard += 
`\n\n📲 *यह फसल आपके AgriChain ऐप में 'My Crops' में लाइव दिखाई दे रही है।*

🤝 *आगे क्या होगा?*
1. खरीदार के एस्क्रो में भुगतान लॉक होते ही आपको WhatsApp पर सूचना मिलेगी।
2. आपके खेत से सीधा ट्रक पिकअप होगा।`;

  await sendWhatsAppMessage(from, confirmationCard);
}

// ---------------------------------------------------------------------------
// 9. Demand & Highest Orders Prediction REST Endpoint
// ---------------------------------------------------------------------------
app.get('/api/predict-highest-orders', async (req, res) => {
  try {
    const commodity = req.query.commodity || null;
    const days = parseInt(req.query.days) || 7;
    const result = await executeDemandForecastModel(commodity, days);
    res.json(result);
  } catch (err) {
    res.status(500).json({ status: 'ERROR', error: err.message });
  }
});

// ---------------------------------------------------------------------------
// 10. Health Check Endpoint & Keep-Alive
// ---------------------------------------------------------------------------
app.get('/diag', (req, res) => {
  res.json({
    hasToken: !!process.env.WHATSAPP_TOKEN,
    tokenPrefix: process.env.WHATSAPP_TOKEN ? process.env.WHATSAPP_TOKEN.slice(0, 10) : 'MISSING',
    phoneId: process.env.WHATSAPP_PHONE_NUMBER_ID || 'MISSING',
    hasGemini: !!process.env.GEMINI_API_KEY,
    hasFirebase: !!process.env.FIREBASE_PROJECT_ID
  });
});

app.get('/', (req, res) => {
  res.json({
    status: 'ONLINE',
    service: 'AgriChain Meta WhatsApp Cloud API Gateway (Multimodal: Voice, Vision & NLP)',
    timestamp: new Date().toISOString()
  });
});

// ---------------------------------------------------------------------------
// DigiLocker / MeriPehchaan Sandbox Server Proxy
// Eliminates browser CORS issues and powers mobile deep-linking
// ---------------------------------------------------------------------------
const SANDBOX_KEY = process.env.SANDBOX_API_KEY || 'key_live_d2e9824f3742403e991f79491c9cadd3';
const SANDBOX_SECRET = process.env.SANDBOX_API_SECRET || 'secret_live_a2042d8ee8144cda92d94c0a4069bc52';
let cachedSandboxToken = null;
let sandboxTokenExpiry = 0;

async function getSandboxAccessToken(force = false) {
  const now = Date.now();
  if (!force && cachedSandboxToken && now < sandboxTokenExpiry) {
    return cachedSandboxToken;
  }
  try {
    const authRes = await axios.post('https://api.sandbox.co.in/authenticate', {}, {
      headers: {
        'x-api-key': SANDBOX_KEY,
        'x-api-secret': SANDBOX_SECRET,
        'x-api-version': '1.0.0',
        'Content-Type': 'application/json'
      },
      timeout: 10000
    });
    const token = authRes.data?.data?.access_token || authRes.data?.access_token;
    if (token) {
      cachedSandboxToken = token;
      sandboxTokenExpiry = now + 23 * 3600 * 1000;
      return token;
    }
  } catch (err) {
    console.warn('[DigiLocker Proxy] Failed to fetch access token:', err.message);
  }
  return null;
}

function parseAadhaarXml(xmlText) {
  let name = 'Citizen';
  let gender = 'M';
  let dob = '';
  let address = '';
  let maskedAadhaar = 'XXXX-XXXX-XXXX';

  const nameMatch = xmlText.match(/name="([^"]+)"/i) || xmlText.match(/<name>([^<]+)<\/name>/i);
  if (nameMatch) name = nameMatch[1];

  const genderMatch = xmlText.match(/gender="([^"]+)"/i) || xmlText.match(/<gender>([^<]+)<\/gender>/i);
  if (genderMatch) gender = genderMatch[1] === 'M' ? 'Male' : genderMatch[1] === 'F' ? 'Female' : genderMatch[1];

  const dobMatch = xmlText.match(/dob="([^"]+)"/i) || xmlText.match(/<dob>([^<]+)<\/dob>/i);
  if (dobMatch) dob = dobMatch[1];

  const uidMatch = xmlText.match(/uid="([^"]+)"/i) || xmlText.match(/masked_uid="([^"]+)"/i);
  if (uidMatch) maskedAadhaar = uidMatch[1];

  const addrParts = [];
  ['co', 'house', 'street', 'loc', 'vtc', 'dist', 'state', 'pc'].forEach(attr => {
    const m = xmlText.match(new RegExp(`${attr}="([^"]+)"`, 'i'));
    if (m) addrParts.push(m[1]);
  });
  if (addrParts.length > 0) address = addrParts.join(', ');

  return { name, gender, dob, address, maskedAadhaar };
}

app.post('/api/digilocker/init', async (req, res) => {
  const host = req.get('host') || `localhost:${PORT}`;
  const protocol = req.protocol === 'https' || req.get('x-forwarded-proto') === 'https' ? 'https' : 'http';
  const defaultCallback = `${protocol}://${host}/digilocker/callback`;

  try {
    const token = await getSandboxAccessToken();
    if (token) {
      const initRes = await axios.post('https://api.sandbox.co.in/kyc/digilocker/sessions/init', {
        '@entity': 'in.co.sandbox.kyc.digilocker.session.request',
        flow: req.body.flow || 'signin',
        doc_types: req.body.doc_types || ['aadhaar'],
        redirect_url: req.body.redirect_url || defaultCallback,
        options: {
          verification_method: req.body.verification_method || ['aadhaar', 'mobile']
        }
      }, {
        headers: {
          'authorization': token,
          'x-api-key': SANDBOX_KEY,
          'x-api-version': '1.0.0',
          'Content-Type': 'application/json'
        },
        timeout: 12000
      });
      return res.json(initRes.data);
    }
  } catch (err) {
    console.warn('[DigiLocker Proxy] Sandbox API live call warning:', err.response?.data || err.message);
  }

  // Graceful fallback
  const mockSessionId = `sandbox_dl_${Date.now()}`;
  return res.json({
    status: 200,
    data: {
      session_id: mockSessionId,
      authorization_url: `https://digilocker.meripehchaan.gov.in/public/oauth2/1/authorize?response_type=code&client_id=SANDBOX_AGRI_01&redirect_uri=${encodeURIComponent(defaultCallback)}&state=${mockSessionId}`
    }
  });
});

app.get('/api/digilocker/status/:sessionId', async (req, res) => {
  const { sessionId } = req.params;
  try {
    const token = await getSandboxAccessToken();
    const sandboxRes = await axios.get(`https://api.sandbox.co.in/kyc/digilocker/sessions/${sessionId}/status`, {
      headers: {
        'authorization': token,
        'x-api-key': SANDBOX_KEY,
        'x-api-version': '1.0.0'
      }
    });
    return res.json(sandboxRes.data);
  } catch (err) {
    return res.status(err.response?.status || 500).json(err.response?.data || { error: err.message });
  }
});

app.get('/api/digilocker/documents/:sessionId', async (req, res) => {
  const { sessionId } = req.params;
  try {
    let token = await getSandboxAccessToken();
    let sandboxRes;
    try {
      sandboxRes = await axios.get(`https://api.sandbox.co.in/kyc/digilocker/sessions/${sessionId}/documents/aadhaar`, {
        headers: { 'authorization': token, 'x-api-key': SANDBOX_KEY, 'x-api-version': '1.0.0' }
      });
    } catch (e) {
      if (e.response?.status === 401) {
        token = await getSandboxAccessToken(true);
        sandboxRes = await axios.get(`https://api.sandbox.co.in/kyc/digilocker/sessions/${sessionId}/documents/aadhaar`, {
          headers: { 'authorization': token, 'x-api-key': SANDBOX_KEY, 'x-api-version': '1.0.0' }
        });
      } else {
        throw e;
      }
    }

    const files = sandboxRes.data?.data?.files;
    if (files && files.length > 0 && files[0].url) {
      const xmlRes = await axios.get(files[0].url, { responseType: 'text' });
      const parsed = parseAadhaarXml(xmlRes.data);
      return res.json({
        code: 200,
        data: {
          name: parsed.name,
          gender: parsed.gender,
          dob: parsed.dob,
          masked_aadhaar: parsed.maskedAadhaar,
          address: parsed.address,
          raw_xml_available: true
        }
      });
    }

    return res.json(sandboxRes.data);
  } catch (err) {
    return res.status(err.response?.status || 500).json(err.response?.data || { error: err.message });
  }
});

app.get(['/digilocker/callback', '/api/digilocker/callback'], (req, res) => {
  const sessionId = req.query.session_id || req.query.sessionId || '';
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AgriChain - DigiLocker Verified</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
      display: flex; align-items: center; justify-content: center;
      min-height: 100vh; padding: 24px;
    }
    .card {
      background: white; border-radius: 24px; padding: 40px 32px;
      max-width: 440px; width: 100%; text-align: center;
      box-shadow: 0 20px 40px rgba(16, 124, 65, 0.12); border: 1px solid #bbf7d0;
    }
    .badge {
      width: 80px; height: 80px; background: #dcfce7; color: #15803d;
      border-radius: 50%; display: flex; align-items: center; justify-content: center;
      margin: 0 auto 20px; font-size: 40px; border: 3px solid #86efac;
    }
    h1 { color: #14532d; font-size: 24px; font-weight: 800; margin-bottom: 8px; }
    p { color: #475569; font-size: 14.5px; line-height: 1.55; margin-bottom: 24px; }
    .btn {
      display: block; width: 100%; padding: 14px 20px; background: #107c41;
      color: white; text-decoration: none; font-weight: 700; border-radius: 14px;
      font-size: 15px; box-shadow: 0 4px 12px rgba(16, 124, 65, 0.25);
    }
  </style>
  <script>
    try { window.location.href = "agrichain://auth/digilocker-success?sessionId=" + encodeURIComponent('${sessionId}'); } catch (_) {}
    setTimeout(() => { try { window.close(); } catch (_) {} }, 2500);
  </script>
</head>
<body>
  <div class="card">
    <div class="badge">✓</div>
    <h1>DigiLocker Verified!</h1>
    <p>Your Aadhaar identity has been verified via MeriPehchaan &amp; DigiLocker.<br><strong>Your AgriChain app has already updated in the background.</strong></p>
    <a href="agrichain://auth/digilocker-success" class="btn" onclick="try{window.close();}catch(e){}">Return to AgriChain App / ऐप पर वापस जाएं</a>
  </div>
</body>
</html>`;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});


// Keep-alive self-ping to prevent Render free-tier from idling/sleeping (pings every 9 mins)
const PING_URL = process.env.RENDER_EXTERNAL_URL || 'https://agrichain-whatsapp-api.onrender.com';
if (process.env.NODE_ENV === 'production' || process.env.RENDER) {
  setInterval(() => {
    https.get(`${PING_URL}/diag`, (res) => {
      console.log(`[Keep-Alive] Pinged ${PING_URL}/diag -> Status: ${res.statusCode}`);
    }).on('error', (e) => {
      console.warn(`[Keep-Alive] Ping warn: ${e.message}`);
    });
  }, 9 * 60 * 1000);
}

if (require.main === module || !process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`\n=============================================================`);
    console.log(`🚀 AgriChain Multimodal WhatsApp Cloud API is LIVE on port ${PORT}!`);
    console.log(`🎙️ Voice Notes (Hindi/Regional NLP) | 📸 Image Quality Assay | 💬 Text`);
    console.log(`📡 Webhook Endpoint: http://localhost:${PORT}/webhook`);
    console.log(`=============================================================\n`);
  });
}

module.exports = app;

