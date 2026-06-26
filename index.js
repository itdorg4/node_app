const express = require('express');

const PORT = process.env.PORT || 3000;

const app = express();

app.get('/', (req, res) => {
  res.type('html').send('<h1 style="text-align: center; margin-top: 20%;">Welcome</h1>');
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
