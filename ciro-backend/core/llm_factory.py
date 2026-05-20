"""
CIRO LLM Factory — Google Gemini fallback chain.

Tries Google Gemini models in priority order:
  1. gemini-2.0-flash (GOOGLE_API_KEY)
  2. gemini-1.5-flash (GOOGLE_API_KEY)
  3. gemini-1.5-pro   (GOOGLE_API_KEY)

Returns the first model that initialises successfully.
"""

import logging
import os
from dotenv import load_dotenv
load_dotenv()
from langchain_core.language_models.chat_models import BaseChatModel

logger = logging.getLogger(__name__)


def get_llm(temperature: float = 0.2) -> BaseChatModel:
    """
    Return a ready-to-use LangChain chat model, trying Google Gemini models in
    priority order: gemini-2.0-flash → gemini-1.5-flash → gemini-1.5-pro.

    Raises ``RuntimeError`` if no provider is available or initialization fails.
    """
    google_key = os.getenv("GOOGLE_API_KEY", "").strip()
    if not google_key:
        raise RuntimeError(
            "GOOGLE_API_KEY is not configured in your environment or .env file. "
            "Please add GOOGLE_API_KEY to proceed with Google Antigravity/Gemini."
        )

    from langchain_google_genai import ChatGoogleGenerativeAI

    models_to_try = [
        "gemini-2.0-flash",
        "gemini-1.5-flash",
        "gemini-1.5-pro",
    ]

    for model_name in models_to_try:
        try:
            logger.info("Attempting to initialize Google Gemini model: %s", model_name)
            llm = ChatGoogleGenerativeAI(
                model=model_name,
                temperature=temperature,
                google_api_key=google_key,
            )
            logger.info("LLM provider successfully initialized: Google Gemini (%s)", model_name)
            return llm
        except Exception as exc:
            logger.warning("Gemini model %s initialization failed (%s). Trying next fallback...", model_name, exc)

    raise RuntimeError(
        "Failed to initialize any of the Google Gemini models. "
        "Please check your GOOGLE_API_KEY validity and quota limit."
    )

