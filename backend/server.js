import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const PORT = parseInt(process.env.BACKEND_PORT || '3000', 10);
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const OPENROUTER_MODEL = (process.env.OPENROUTER_MODEL || 'gpt-4o-mini').trim();
const OPENROUTER_BASE_URL = (process.env.OPENROUTER_BASE_URL || 'https://api.openrouter.ai/v1')
  .replace(/\/$/, '')
  .replace(/,/g, '.');

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

function buildOpenRouterPayload(messages, temperature, maxTokens) {
  return {
    model: OPENROUTER_MODEL,
    messages,
    temperature,
    max_tokens: maxTokens,
  };
}

async function sendOpenRouterRequest(payload) {
  const url = `${OPENROUTER_BASE_URL}/chat/completions`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`OpenRouter request failed: ${response.status} ${errorBody}`);
  }

  return response.json();
}

app.post('/api/llm/chat', async (req, res) => {
  if (!OPENROUTER_API_KEY) {
    return res.status(503).json({ error: 'LLM backend is not configured. Set OPENROUTER_API_KEY.' });
  }

  const messages = req.body.messages;
  const temperature = Number(req.body.temperature ?? 0.7);
  const maxTokens = Number(req.body.max_tokens_to_sample ?? req.body.max_tokens ?? 1000);

  if (!Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'No messages provided' });
  }

  const payload = buildOpenRouterPayload(messages, temperature, maxTokens);

  try {
    const data = await sendOpenRouterRequest(payload);
    const completion = data?.choices?.[0]?.message?.content?.trim() ??
      data?.choices?.[0]?.delta?.content?.trim();

    if (!completion) {
      return res.status(500).json({ error: 'LLM response missing answer text', details: data });
    }

    return res.json({ success: true, data: { completion, raw: data } });
  } catch (error) {
    return res.status(500).json({ error: 'LLM request error', details: error?.toString() });
  }
});

app.listen(PORT, () => {
  console.log(`Backend server running on http://localhost:${PORT}`);
});
