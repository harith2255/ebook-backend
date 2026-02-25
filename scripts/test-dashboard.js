import http from 'http';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
dotenv.config();

const token = jwt.sign(
  {id: '782c37df-f571-4390-bd69-fefdb0e13cf5', email: 'harith@gmail.com', role: 'User'}, 
  process.env.JWT_SECRET || 'change-me-in-production'
);

const req = http.request({
  hostname: 'localhost',
  port: 5000,
  path: '/api/dashboard',
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${token}`
  }
}, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Body: ${data}`);
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

req.end();
