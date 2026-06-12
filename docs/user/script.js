document.addEventListener('DOMContentLoaded', () => {
  // --- UI Elements ---
  const accordions = document.querySelectorAll('.accordion-title');
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

  // --- Accordion Logic ---
  accordions.forEach(acc => {
    acc.addEventListener('click', () => {
      const item = acc.parentElement;
      const isOpen = item.classList.contains('open');
      
      // Close other open accordions
      document.querySelectorAll('.accordion-item').forEach(i => i.classList.remove('open'));
      
      if (!isOpen) {
        item.classList.add('open');
      }
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
      tokenBanner.style.backgroundColor = '#d4edda';
      tokenBanner.style.borderBottomColor = '#c3e6cb';
      tokenBanner.innerHTML = '<span>Key configured successfully. ✅</span><button id="open-config-btn">Edit Key 🔑</button>';
      // Re-bind click event to newly created button
      document.getElementById('open-config-btn').addEventListener('click', openModal);
    } else {
      tokenBanner.style.backgroundColor = '#fff3cd';
      tokenBanner.style.borderBottomColor = '#ffeeba';
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
    // Scrape all text elements under doc-content-root
    const selector = '#doc-content-root h1, #doc-content-root h2, #doc-content-root h3, #doc-content-root p, #doc-content-root li, #doc-content-root strong';
    const elements = document.querySelectorAll(selector);
    let scrapedText = '';

    elements.forEach(el => {
      // Exclude titles or headings already in chat sidebar or badges
      const parentSection = el.closest('section');
      const sectionName = parentSection ? parentSection.id.toUpperCase() : 'GENERAL';
      scrapedText += `[${sectionName}] ${el.innerText.trim()}\n`;
    });

    return scrapedText;
  }

  // --- Grounded AI Query logic ---
  async function handleSend() {
    const query = chatInput.value.trim();
    if (!query) return;

    // Display user bubble
    appendMessage(query, 'user');
    chatInput.value = '';

    const apiKey = getStoredKey();
    if (!apiKey) {
      appendMessage('I need an OpenRouter API Key to process queries! Please click "Configure Key" in the top banner and paste your sk-or-v1-... token.', 'bot');
      openModal();
      return;
    }

    // Scrape latest context
    const docsContext = scrapeDocumentation();

    // Display loading bubble
    const loadingId = appendMessage('Consulting guides...', 'bot loading');

    try {
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'HTTP-Referer': window.location.origin,
          'X-Title': 'BabyShopHub Grounded Help Center'
        },
        body: JSON.stringify({
          model: 'google/gemini-2.5-flash', // High performance efficient LLM
          messages: [
            {
              role: 'system',
              content: `You are a helpful, expert parent guide assistant for the BabyShopHub mobile app. You are strictly GROUNDED in the provided documentation context below.

Here is the ONLY documentation context you have access to:
---
${docsContext}
---

RULES:
1. ONLY answer questions using facts directly stated in the documentation context above. Do NOT make up, assume, or extrapolate details that are not clearly mentioned.
2. If a query is outside the scope of the documentation (e.g. general questions like "What is the capital of France?", coding help, or products/policies not listed above), you MUST politely decline to answer, explaining that your expertise is strictly bounded by the BabyShopHub parent guidelines.
3. Keep answers friendly, accurate, helpful, and concise.`
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
        appendMessage('Oops, received an unexpected result from OpenRouter. Please verify your token details and quota.', 'bot');
      }
    } catch (error) {
      removeMessage(loadingId);
      appendMessage('Connection error. Please check your internet connectivity or API credentials.', 'bot');
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
