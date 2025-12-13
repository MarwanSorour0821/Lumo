const jwt = require("jsonwebtoken");
const fs = require("fs");

const privateKey = fs.readFileSync("AuthKey_XBRQWH24DX.p8");

const teamId = "C7RJ365M46"; // Apple Team ID
const clientId = "com.lumobloodapp.app"; // Service ID
const keyId = "XBRQWH24DX"; // Apple Key ID

const token = jwt.sign(
  {
    iss: teamId,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 180, // 6 months
    aud: "https://appleid.apple.com",
    sub: clientId,
  },
  privateKey,
  {
    algorithm: "ES256",
    keyid: keyId,
  }
);

console.log(token);


