"""
CIRO LLM Factory — Google Gemini & Groq fallback chain.

Tries Google Gemini models first:
  1. gemini-2.0-flash (GOOGLE_API_KEY)
  2. gemini-1.5-flash (GOOGLE_API_KEY)
  3. gemini-1.5-pro   (GOOGLE_API_KEY)

If Gemini fails or is throttled (429), falls back to Groq models:
  1. llama-3.3-70b-versatile (GROQ_API_KEY)
  2. llama3-8b-8192           (GROQ_API_KEY)

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
    
    If Gemini fails or GOOGLE_API_KEY is missing, falls back to Groq models:
    llama-3.3-70b-versatile → llama3-8b-8192.

    Raises ``RuntimeError`` if no provider is available or initialization fails.
    """
    google_key = os.getenv("GOOGLE_API_KEY", "").strip()
    groq_key = os.getenv("GROQ_API_KEY", "").strip()

    # 1. Try Google Gemini Models (with built-in exponential retries)
    if google_key:
        from langchain_google_genai import ChatGoogleGenerativeAI

        models_to_try = [
            "gemini-2.0-flash",
            "gemini-1.5-flash",
            "gemini-1.5-pro",
        ]

        for model_name in models_to_try:
            try:
                logger.info("Attempting to initialize Google Gemini model: %s (max_retries=5)", model_name)
                llm = ChatGoogleGenerativeAI(
                    model=model_name,
                    temperature=temperature,
                    google_api_key=google_key,
                    max_retries=5,
                )
                logger.info("LLM provider successfully initialized: Google Gemini (%s)", model_name)
                return llm
            except Exception as exc:
                logger.warning("Gemini model %s initialization failed (%s). Trying next option...", model_name, exc)

    # 2. Try Groq Models (as standard fallback when Gemini is offline or rate-limited)
    if groq_key:
        try:
            from langchain_groq import ChatGroq

            groq_models = [
                "llama-3.3-70b-versatile",
                "llama3-8b-8192",
            ]

            for model_name in groq_models:
                try:
                    logger.info("Attempting to initialize Groq model fallback: %s (max_retries=5)", model_name)
                    llm = ChatGroq(
                        model=model_name,
                        temperature=temperature,
                        groq_api_key=groq_key,
                        max_retries=5,
                    )
                    logger.info("LLM provider successfully initialized: Groq (%s)", model_name)
                    return llm
                except Exception as exc:
                    logger.warning("Groq model %s initialization failed (%s). Trying next option...", model_name, exc)
        except ImportError as e:
            logger.warning("Failed to import langchain_groq for fallback (%s).", e)

    # 3. No configuration found or initialization completely failed
    if not google_key and not groq_key:
        raise RuntimeError(
            "No LLM API keys (GOOGLE_API_KEY or GROQ_API_KEY) are configured in your environment. "
            "Please configure at least one API key in your .env file to proceed."
        )

    raise RuntimeError(
        "Failed to initialize any of the Google Gemini or Groq fallback models. "
        "Please check your API key validity and quota limits."
    )


