document.addEventListener('DOMContentLoaded', () => {
  // --- UI Elements ---
  const chatTrigger = document.getElementById('chat-trigger');
  const chatClose = document.getElementById('chat-close');
  const chatWindow = document.getElementById('chat-window');
  const chatInput = document.getElementById('chat-input');
  const chatSend = document.getElementById('chat-send');
  const chatMessages = document.getElementById('chat-messages');
  
  const tokenBanner = document.getElementById('token-banner');
  const openConfigBtn = document.getElementById('open-config-btn');
  const configModal = document.getElementById('config-modal');
  const apiKeyInput = document.getElementById('api-key-input');
  const btnConfigCancel = document.getElementById('btn-config-cancel');
  const btnConfigSave = document.getElementById('btn-config-save');

  // --- Sidebar navigation highlight logic ---
  const navLinks = document.querySelectorAll('.side-nav a');
  navLinks.forEach(link => {
    link.addEventListener('click', () => {
      navLinks.forEach(l => l.classList.remove('active'));
      link.classList.add('active');
    });
  });

  // --- Chat Window Toggle ---
  chatTrigger.addEventListener('click', () => {
    chatWindow.classList.add('open');
    chatTrigger.style.display = 'none';
  });

  chatClose.addEventListener('click', () => {
    chatWindow.classList.remove('open');
    chatTrigger.style.display = 'flex';
  });

  // --- API Key Management ---
  function getStoredKey() {
    return localStorage.getItem('openrouter_api_key') || '';
  }

  function setStoredKey(key) {
    localStorage.setItem('openrouter_api_key', key.trim());
    updateTokenUI();
  }

  function updateTokenUI() {
    const key = getStoredKey();
    if (key) {
      tokenBanner.style.backgroundColor = 'rgba(74, 246, 38, 0.1)';
      tokenBanner.style.borderBottomColor = 'rgba(74, 246, 38, 0.2)';
      tokenBanner.style.color = '#4af626';
      tokenBanner.innerHTML = '<span>Key configured successfully. ✅</span><button id="open-config-btn">Edit Key 🔑</button>';
      document.getElementById('open-config-btn').addEventListener('click', openModal);
    } else {
      tokenBanner.style.backgroundColor = 'rgba(255, 193, 7, 0.1)';
      tokenBanner.style.borderBottomColor = 'rgba(255, 193, 7, 0.2)';
      tokenBanner.style.color = '#ffc107';
      tokenBanner.innerHTML = '<span>OpenRouter API Key needed for AI Chat.</span><button id="open-config-btn">Configure Key 🔑</button>';
      document.getElementById('open-config-btn').addEventListener('click', openModal);
    }
  }

  function openModal() {
    apiKeyInput.value = getStoredKey();
    configModal.classList.add('open');
  }

  function closeModal() {
    configModal.classList.remove('open');
  }

  openConfigBtn.addEventListener('click', openModal);
  btnConfigCancel.addEventListener('click', closeModal);
  btnConfigSave.addEventListener('click', () => {
    setStoredKey(apiKeyInput.value);
    closeModal();
  });

  updateTokenUI();

  // --- Dynamic Document Scraper (Grounding Context) ---
  function scrapeDocumentation() {
    const selector = '#doc-content-root h1, #doc-content-root h2, #doc-content-root h3, #doc-content-root p, #doc-content-root li, #doc-content-root code, #doc-content-root strong';
    const elements = document.querySelectorAll(selector);
    let scrapedText = '';

    elements.forEach(el => {
      const parentSection = el.closest('section');
      const sectionName = parentSection ? parentSection.id.toUpperCase() : 'GENERAL';
      
      // Prevent scraping conversational prompts from within chat bubble itself
      if (!el.closest('.chat-window')) {
        scrapedText += `[${sectionName}] ${el.innerText.trim()}\n`;
      }
    });

    return scrapedText;
  }

  // --- Grounded AI Query logic ---
  async function handleSend() {
    const query = chatInput.value.trim();
    if (!query) return;

    appendMessage(query, 'user');
    chatInput.value = '';

    const apiKey = getStoredKey();
    if (!apiKey) {
      appendMessage('I need an OpenRouter API Key to process queries! Please click "Configure Key" and save your token.', 'bot');
      openModal();
      return;
    }

    const docsContext = scrapeDocumentation();
    const loadingId = appendMessage('Reading system specs...', 'bot loading');

    try {
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'HTTP-Referer': window.location.origin,
          'X-Title': 'BabyShopHub Grounded Developer Guidelines'
        },
        body: JSON.stringify({
          model: 'google/gemini-2.5-flash',
          messages: [
            {
              role: 'system',
              content: `You are an expert, friendly System Engineer and Developer Assistant for the BabyShopHub project. You are strictly GROUNDED in the provided technical documentation context below.

Here is the ONLY documentation context you have access to:
---
${docsContext}
---

RULES:
1. ONLY answer questions using exact facts, folder names, code structures, or command guides stated in the developer documentation context above. Do NOT assume, invent, or speculate on options that are not explicitly documented.
2. If a query is outside the scope of this technical documentation (e.g. general questions like "Write a python sorting algorithm", or policies/questions meant for normal parents not described above), you MUST politely refuse to answer, explaining that your expert knowledge is bounded strictly by the BabyShopHub developer architecture portal.
3. Keep answers high-quality, professional, helpful, and concise. Render code examples using Markdown blocks.`
            },
            {
              role: 'user',
              content: query
            }
          ]
        })
      });

      const data = await response.json();
      removeMessage(loadingId);

      if (data.choices && data.choices[0] && data.choices[0].message) {
        const reply = data.choices[0].message.content;
        appendMessage(reply, 'bot');
      } else {
        appendMessage('Oops, received an unexpected result from OpenRouter. Please check your token key or network quota.', 'bot');
      }
    } catch (error) {
      removeMessage(loadingId);
      appendMessage('Network connection error. Check your API settings.', 'bot');
      console.error(error);
    }
  }

  // Helper UI methods
  function appendMessage(text, className) {
    const bubble = document.createElement('div');
    const msgId = 'msg_' + Date.now();
    bubble.id = msgId;
    bubble.className = `message ${className}`;
    bubble.innerHTML = `<p>${text.replace(/\n/g, '<br/>')}</p>`;
    chatMessages.appendChild(bubble);
    chatMessages.scrollTop = chatMessages.scrollHeight;
    return msgId;
  }

  function removeMessage(id) {
    const bubble = document.getElementById(id);
    if (bubble) bubble.remove();
  }

  // --- Send Triggers ---
  chatSend.addEventListener('click', handleSend);
  chatInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') handleSend();
  });
});
