"""
CIRO LLM Factory — provider fallback chain.

Tries LLM providers in priority order:
  1. Gemini  (GOOGLE_API_KEY)   → ChatGoogleGenerativeAI
  2. Groq    (GROQ_API_KEY)     → ChatGroq
  3. GLM     (GLM_API_KEY)      → ChatOpenAI (OpenAI-compatible endpoint)

Returns the first provider that initialises successfully.
"""

import logging
import os
from dotenv import load_dotenv
load_dotenv()
from langchain_core.language_models.chat_models import BaseChatModel

logger = logging.getLogger(__name__)

# GLM (Zhipu AI) OpenAI-compatible endpoint
_GLM_BASE_URL = "https://open.bigmodel.cn/api/paas/v4"


def get_llm(temperature: float = 0.2) -> BaseChatModel:
    """
    Return a ready-to-use LangChain chat model, trying providers in
    priority order: Gemini → Groq → GLM.

    Raises ``RuntimeError`` if no provider is available.
    """

    # ── 1. Gemini ─────────────────────────────────────────────────
    google_key = os.getenv("GOOGLE_API_KEY", "").strip()
    if google_key:
        try:
            from langchain_google_genai import ChatGoogleGenerativeAI

            llm = ChatGoogleGenerativeAI(
                model="gemini-2.0-flash",
                temperature=temperature,
                google_api_key=google_key,
            )
            logger.info("LLM provider selected: Gemini (gemini-2.0-flash)")
            return llm
        except Exception as exc:
            logger.warning("Gemini init failed (%s), trying next provider…", exc)

    # ── 2. Groq ───────────────────────────────────────────────────
    groq_key = os.getenv("GROQ_API_KEY", "").strip()
    if groq_key:
        try:
            from langchain_groq import ChatGroq

            llm = ChatGroq(
                model="llama-3.3-70b-versatile",
                temperature=temperature,
                groq_api_key=groq_key,
            )
            logger.info("LLM provider selected: Groq (llama-3.3-70b-versatile)")
            return llm
        except Exception as exc:
            logger.warning("Groq init failed (%s), trying next provider…", exc)

    # ── 3. GLM (Zhipu AI — OpenAI-compatible) ─────────────────────
    glm_key = os.getenv("GLM_API_KEY", "").strip()
    if glm_key:
        try:
            from langchain_openai import ChatOpenAI

            llm = ChatOpenAI(
                model="glm-4-flash",
                temperature=temperature,
                openai_api_key=glm_key,
                openai_api_base=_GLM_BASE_URL,
            )
            logger.info("LLM provider selected: GLM / Zhipu AI (glm-4-flash)")
            return llm
        except Exception as exc:
            logger.warning("GLM init failed (%s), no more providers.", exc)

    # ── nothing worked ────────────────────────────────────────────
    raise RuntimeError(
        "No LLM provider available. Set at least one of: "
        "GOOGLE_API_KEY, GROQ_API_KEY, or GLM_API_KEY in your .env file."
    )
