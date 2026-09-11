const http = require('http');
const https = require('https');
const url = require('url');

const PORT = 8088;
const API_KEY = 'key_live_d2e9824f3742403e991f79491c9cadd3';
const API_SECRET = 'secret_live_a2042d8ee8144cda92d94c0a4069bc52';
const API_VERSION = '1.0.0';

let cachedToken = null;
let tokenExpiry = 0;

function httpRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(body) });
        } catch (_) {
          resolve({ status: res.statusCode, headers: res.headers, raw: body });
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(15000, () => {
      req.destroy();
      reject(new Error('Timeout'));
    });
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

async function getAccessToken(force = false) {
  const now = Date.now();
  if (!force && cachedToken && now < tokenExpiry) {
    return cachedToken;
  }
  const res = await httpRequest({
    hostname: 'api.sandbox.co.in',
    path: '/authenticate',
    method: 'POST',
    headers: {
      'x-api-key': API_KEY,
      'x-api-secret': API_SECRET,
      'x-api-version': API_VERSION,
      'Content-Type': 'application/json'
    }
  });

  const token = res.body?.data?.access_token || res.body?.access_token;
  if (!token) {
    throw new Error('Could not acquire Sandbox access token: ' + JSON.stringify(res.body));
  }
  cachedToken = token;
  tokenExpiry = now + 23 * 3600 * 1000;
  console.log('[Sandbox Proxy] Live access token refreshed successfully.');
  return token;
}

// Parse Aadhaar XML helper
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
  if (uidMatch) {
    maskedAadhaar = uidMatch[1];
  }

  // Address parts: co, house, street, loc, vtc, dist, state, pc
  const addrParts = [];
  const coMatch = xmlText.match(/co="([^"]+)"/i);
  if (coMatch) addrParts.push(coMatch[1]);
  const houseMatch = xmlText.match(/house="([^"]+)"/i);
  if (houseMatch) addrParts.push(houseMatch[1]);
  const streetMatch = xmlText.match(/street="([^"]+)"/i);
  if (streetMatch) addrParts.push(streetMatch[1]);
  const locMatch = xmlText.match(/loc="([^"]+)"/i);
  if (locMatch) addrParts.push(locMatch[1]);
  const vtcMatch = xmlText.match(/vtc="([^"]+)"/i);
  if (vtcMatch) addrParts.push(vtcMatch[1]);
  const distMatch = xmlText.match(/dist="([^"]+)"/i);
  if (distMatch) addrParts.push(distMatch[1]);
  const stateMatch = xmlText.match(/state="([^"]+)"/i);
  if (stateMatch) addrParts.push(stateMatch[1]);
  const pcMatch = xmlText.match(/pc="([^"]+)"/i);
  if (pcMatch) addrParts.push(pcMatch[1]);

  if (addrParts.length > 0) {
    address = addrParts.join(', ');
  }

  return { name, gender, dob, address, maskedAadhaar };
}

const server = http.createServer(async (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  try {
    // 1. Health check
    if (pathname === '/health' || pathname === '/') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ status: 'ok', service: 'Sandbox DigiLocker Proxy', port: PORT }));
    }

    // 2. Initiate Session: POST /api/digilocker/init
    if (pathname === '/api/digilocker/init' && req.method === 'POST') {
      let bodyData = '';
      req.on('data', chunk => bodyData += chunk);
      req.on('end', async () => {
        try {
          const clientPayload = bodyData ? JSON.parse(bodyData) : {};
          const token = await getAccessToken();

          const sandboxPayload = JSON.stringify({
            '@entity': 'in.co.sandbox.kyc.digilocker.session.request',
            flow: clientPayload.flow || 'signin',
            doc_types: clientPayload.doc_types || ['aadhaar'],
            redirect_url: clientPayload.redirect_url || 'https://sandbox.co.in',
            options: {
              verification_method: clientPayload.verification_method || ['aadhaar', 'mobile']
            }
          });

          const sandboxRes = await httpRequest({
            hostname: 'api.sandbox.co.in',
            path: '/kyc/digilocker/sessions/init',
            method: 'POST',
            headers: {
              'Authorization': token,
              'x-api-key': API_KEY,
              'x-api-version': API_VERSION,
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(sandboxPayload)
            }
          }, sandboxPayload);

          console.log('[Sandbox Proxy] Session Init Status:', sandboxRes.status);
          res.writeHead(sandboxRes.status, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(sandboxRes.body));
        } catch (err) {
          console.error('[Sandbox Proxy] Error in /api/digilocker/init:', err.message);
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: err.message }));
        }
      });
      return;
    }

    // 3. Status check: GET /api/digilocker/status/:sessionId
    if (pathname.startsWith('/api/digilocker/status/')) {
      const sessionId = pathname.replace('/api/digilocker/status/', '').trim();
      const token = await getAccessToken();

      const sandboxRes = await httpRequest({
        hostname: 'api.sandbox.co.in',
        path: `/kyc/digilocker/sessions/${sessionId}/status`,
        method: 'GET',
        headers: {
          'Authorization': token,
          'x-api-key': API_KEY,
          'x-api-version': API_VERSION
        }
      });

      console.log(`[Sandbox Proxy] Session ${sessionId} Status:`, sandboxRes.body?.data?.status || sandboxRes.status);
      res.writeHead(sandboxRes.status, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(sandboxRes.body));
    }

    // 4. Fetch Document: GET /api/digilocker/documents/:sessionId
    if (pathname.startsWith('/api/digilocker/documents/')) {
      const sessionId = pathname.replace('/api/digilocker/documents/', '').trim();
      const token = await getAccessToken();

      let sandboxRes = await httpRequest({
        hostname: 'api.sandbox.co.in',
        path: `/kyc/digilocker/sessions/${sessionId}/documents/aadhaar`,
        method: 'GET',
        headers: {
          'Authorization': token,
          'x-api-key': API_KEY,
          'x-api-version': API_VERSION
        }
      });

      // If token expired, force refresh and retry once
      if (sandboxRes.status === 401 || sandboxRes.status === 403) {
        console.log('[Sandbox Proxy] Token expired, refreshing and retrying document fetch...');
        const freshToken = await getAccessToken(true);
        sandboxRes = await httpRequest({
          hostname: 'api.sandbox.co.in',
          path: `/kyc/digilocker/sessions/${sessionId}/documents/aadhaar`,
          method: 'GET',
          headers: {
            'Authorization': freshToken,
            'x-api-key': API_KEY,
            'x-api-version': API_VERSION
          }
        });
      }

      console.log(`[Sandbox Proxy] Document Fetch for ${sessionId} Status:`, sandboxRes.status);

      // If files exist, fetch the XML file and extract real citizen information
      const files = sandboxRes.body?.data?.files;
      if (files && files.length > 0 && files[0].url) {
        const fileUrl = files[0].url;
        console.log('[Sandbox Proxy] Downloading Aadhaar XML from S3...');
        
        const xmlDownload = await new Promise((resolve, reject) => {
          https.get(fileUrl, (getRes) => {
            let xmlData = '';
            getRes.on('data', c => xmlData += c);
            getRes.on('end', () => resolve(xmlData));
          }).on('error', reject);
        });

        const parsed = parseAadhaarXml(xmlDownload);
        console.log(`[Sandbox Proxy] Successfully parsed Aadhaar for: ${parsed.name}`);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
          code: 200,
          data: {
            name: parsed.name,
            gender: parsed.gender,
            dob: parsed.dob,
            masked_aadhaar: parsed.maskedAadhaar,
            address: parsed.address,
            raw_xml_available: true
          }
        }));
      }

      res.writeHead(sandboxRes.status, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(sandboxRes.body));
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  } catch (err) {
    console.error('[Sandbox Proxy] Unhandled server error:', err);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message }));
  }
});

server.listen(PORT, () => {
  console.log(`\n======================================================`);
  console.log(`✅ Sandbox.co.in DigiLocker Proxy is running on port ${PORT}`);
  console.log(`🔗 Endpoint: http://localhost:${PORT}/api/digilocker/init`);
  console.log(`======================================================\n`);
});
