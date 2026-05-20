"""
CIRO LLM Factory — Google Gemini & Groq fallback chain.

Tries Google Gemini models first:
  1. gemini-2.0-flash (GOOGLE_API_KEY)
  2. gemini-1.5-flash (GOOGLE_API_KEY)
  3. gemini-1.5-pro   (GOOGLE_API_KEY)

If Gemini is rate-limited during calls, the wrapper will retry with
exponential backoff and then attempt a Groq fallback if configured.
"""

import asyncio
import logging
import os
import time
from typing import Any, Callable

from dotenv import load_dotenv
load_dotenv()
from langchain_core.language_models.chat_models import BaseChatModel

logger = logging.getLogger(__name__)


class RetryableChatModel(BaseChatModel):
    def __init__(
        self,
        model: BaseChatModel,
        provider: str,
        fallback_factory: Callable[[], BaseChatModel] | None = None,
        max_attempts: int = 3,
        backoff_factor: float = 2.0,
    ):
        super().__init__()
        self._model = model
        self._provider = provider
        self._fallback_factory = fallback_factory
        self._max_attempts = max_attempts
        self._backoff_factor = backoff_factor

    def __getattr__(self, name: str) -> Any:
        return getattr(self._model, name)

    def _is_rate_limit_error(self, exc: BaseException) -> bool:
        message = str(exc).lower()
        status_code = getattr(exc, "status_code", None) or getattr(exc, "code", None)

        if isinstance(status_code, int) and status_code == 429:
            return True

        if any(token in message for token in [
            "429",
            "rate limit",
            "too many requests",
            "quota",
            "resourceexhausted",
            "throttl",
        ]):
            return True

        exc_name = exc.__class__.__name__.lower()
        if exc_name in {
            "httperror",
            "resourceexhausted",
            "toomanyrequests",
            "quotaerror",
            "ratelimiterror",
            "rate_limit_error",
        }:
            return True

        if getattr(exc, "__cause__", None) is not None:
            return self._is_rate_limit_error(exc.__cause__)
        if getattr(exc, "__context__", None) is not None:
            return self._is_rate_limit_error(exc.__context__)

        return False

    def _should_retry(self, attempt: int, exc: BaseException) -> bool:
        return self._is_rate_limit_error(exc) and attempt < self._max_attempts

    def _switch_to_fallback(self, exc: BaseException) -> bool:
        if self._fallback_factory is None or self._provider != "gemini":
            return False

        try:
            fallback_model = self._fallback_factory()
            if fallback_model is None:
                return False
            self._model = fallback_model
            self._provider = "groq"
            logger.warning("Switched from Gemini to Groq fallback after rate limit error: %s", exc)
            return True
        except Exception as fallback_exc:
            logger.warning(
                "Groq fallback initialization failed after Gemini rate limit: %s. "
                "Continuing retry on Gemini.",
                fallback_exc,
            )
            return False

    def _retry(self, method_name: str, *args: Any, **kwargs: Any) -> Any:
        last_exc: BaseException | None = None
        for attempt in range(1, self._max_attempts + 1):
            method = getattr(self._model, method_name)
            try:
                return method(*args, **kwargs)
            except Exception as exc:
                last_exc = exc
                if self._switch_to_fallback(exc):
                    continue

                if self._should_retry(attempt, exc):
                    delay = self._backoff_factor ** (attempt - 1)
                    logger.warning(
                        "Rate limit detected on %s (attempt %d/%d). Retrying in %.1f seconds...",
                        method_name,
                        attempt,
                        self._max_attempts,
                        delay,
                    )
                    time.sleep(delay)
                    continue
                raise
        assert last_exc is not None
        raise last_exc

    async def _retry_async(self, method_name: str, *args: Any, **kwargs: Any) -> Any:
        last_exc: BaseException | None = None
        for attempt in range(1, self._max_attempts + 1):
            method = getattr(self._model, method_name)
            try:
                return await method(*args, **kwargs)
            except Exception as exc:
                last_exc = exc
                if self._switch_to_fallback(exc):
                    continue

                if self._should_retry(attempt, exc):
                    delay = self._backoff_factor ** (attempt - 1)
                    logger.warning(
                        "Rate limit detected on async %s (attempt %d/%d). Retrying in %.1f seconds...",
                        method_name,
                        attempt,
                        self._max_attempts,
                        delay,
                    )
                    await asyncio.sleep(delay)
                    continue
                raise
        assert last_exc is not None
        raise last_exc

    @property
    def _llm_type(self) -> str:
        return getattr(self._model, '_llm_type', getattr(self._model, 'llm_type', 'unknown'))

    def _generate(self, *args: Any, **kwargs: Any) -> Any:
        return self._retry('_generate', *args, **kwargs)

    async def _agenerate(self, *args: Any, **kwargs: Any) -> Any:
        return await self._retry_async('_agenerate', *args, **kwargs)

    def bind_tools(self, tool_classes, **kwargs):
        bound_model = self._model.bind_tools(tool_classes, **kwargs)
        if bound_model is not None and bound_model is not self._model:
            self._model = bound_model
        return self

    def invoke(self, input, config=None, *, stop=None, **kwargs):
        return self._retry("invoke", input, config=config, stop=stop, **kwargs)

    async def ainvoke(self, input, config=None, *, stop=None, **kwargs):
        return await self._retry_async("ainvoke", input, config=config, stop=stop, **kwargs)

    def predict(self, *args, **kwargs):
        return self._retry("predict", *args, **kwargs)

    async def apredict(self, *args, **kwargs):
        return await self._retry_async("apredict", *args, **kwargs)

    def predict_messages(self, messages, *, stop=None, **kwargs):
        return self._retry("predict_messages", messages, stop=stop, **kwargs)

    async def apredict_messages(self, messages, *, stop=None, **kwargs):
        return await self._retry_async("apredict_messages", messages, stop=stop, **kwargs)

    def generate(self, messages, stop=None, callbacks=None, *, tags=None, metadata=None, run_name=None, run_id=None, **kwargs):
        return self._retry(
            "generate",
            messages,
            stop=stop,
            callbacks=callbacks,
            tags=tags,
            metadata=metadata,
            run_name=run_name,
            run_id=run_id,
            **kwargs,
        )

    async def agenerate(self, messages, stop=None, callbacks=None, *, tags=None, metadata=None, run_name=None, run_id=None, **kwargs):
        return await self._retry_async(
            "agenerate",
            messages,
            stop=stop,
            callbacks=callbacks,
            tags=tags,
            metadata=metadata,
            run_name=run_name,
            run_id=run_id,
            **kwargs,
        )


def _initialize_groq_model(temperature: float) -> BaseChatModel | None:
    groq_key = os.getenv("GROQ_API_KEY", "").strip()
    if not groq_key:
        return None

    try:
        from langchain_groq import ChatGroq
    except ImportError as exc:
        logger.warning("Failed to import langchain_groq for Groq fallback (%s).", exc)
        return None

    groq_models = [
        "llama-3.3-70b-versatile",
        "llama3-8b-8192",
    ]

    for model_name in groq_models:
        try:
            logger.info("Attempting to initialize Groq fallback model: %s", model_name)
            return ChatGroq(
                model=model_name,
                temperature=temperature,
                groq_api_key=groq_key,
                max_retries=5,
            )
        except Exception as exc:
            logger.warning("Groq fallback model %s initialization failed (%s). Trying next option...", model_name, exc)
    return None


def _wrap_model_with_retry(
    llm: BaseChatModel,
    provider: str,
    fallback_factory: Callable[[], BaseChatModel] | None = None,
) -> BaseChatModel:
    return RetryableChatModel(
        model=llm,
        provider=provider,
        fallback_factory=fallback_factory,
        max_attempts=3,
        backoff_factor=2.0,
    )


def get_llm(temperature: float = 0.2) -> BaseChatModel:
    """
    Return a ready-to-use LangChain chat model with runtime retry support.
    """
    google_key = os.getenv("GOOGLE_API_KEY", "").strip()
    groq_key = os.getenv("GROQ_API_KEY", "").strip()

    def groq_fallback() -> BaseChatModel | None:
        return _initialize_groq_model(temperature=temperature)

    if google_key:
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
                    max_retries=5,
                )
                logger.info("LLM provider successfully initialized: Google Gemini (%s)", model_name)
                return _wrap_model_with_retry(llm, provider="gemini", fallback_factory=groq_fallback)
            except Exception as exc:
                logger.warning("Gemini model %s initialization failed (%s). Trying next option...", model_name, exc)

    if groq_key:
        fallback = _initialize_groq_model(temperature=temperature)
        if fallback is not None:
            return _wrap_model_with_retry(fallback, provider="groq")

    if not google_key and not groq_key:
        raise RuntimeError(
            "No LLM API keys (GOOGLE_API_KEY or GROQ_API_KEY) are configured in your environment. "
            "Please configure at least one API key in your .env file to proceed."
        )

    raise RuntimeError(
        "Failed to initialize any of the Google Gemini or Groq fallback models. "
        "Please check your API key validity and quota limits."
    )


