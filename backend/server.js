import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const PORT = parseInt(process.env.BACKEND_PORT || '3000', 10);
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL || 'claude-3.5';

const app = express();
app.use(cors());
app.use(express.json({ limit: '20mb' }));

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', mode: 'llm-only' });
});

function buildPrompt(messages) {
  if (!Array.isArray(messages)) return '';

  let prompt = '';
  for (const message of messages) {
    const role = (message.role || '').toString().toLowerCase();
    const content = message.content?.toString() ?? '';
    if (role === 'system') {
      prompt += `

System: ${content}`;
    } else if (role === 'assistant') {
      prompt += `

Assistant: ${content}`;
    } else {
      prompt += `

Human: ${content}`;
    }
  }
  prompt += '\n\nAssistant: ';
  return prompt;
}

app.post('/api/llm/chat', async (req, res) => {
  if (!ANTHROPIC_API_KEY) {
    return res.status(503).json({ error: 'LLM backend is not configured. Set ANTHROPIC_API_KEY.' });
  }

  const messages = req.body.messages;
  const temperature = Number(req.body.temperature ?? 0.7);
  const maxTokens = Number(req.body.max_tokens_to_sample ?? 1000);

  const prompt = buildPrompt(messages);
  if (!prompt.trim()) {
    return res.status(400).json({ error: 'No messages provided' });
  }

  try {
    const response = await fetch('https://api.anthropic.com/v1/complete', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': ANTHROPIC_API_KEY,
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        prompt,
        max_tokens_to_sample: maxTokens,
        temperature,
        stop_sequences: ['\n\nHuman:', '\n\nAssistant:'],
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      return res.status(response.status).json({ error: 'LLM request failed', details: errorBody });
    }

    const data = await response.json();
    return res.json({ success: true, data });
  } catch (error) {
    return res.status(500).json({ error: 'LLM request error', details: error?.toString() });
  }
});

app.listen(PORT, () => {
  console.log(`Backend server running on http://localhost:${PORT}`);
});
