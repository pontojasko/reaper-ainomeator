"""
config.py — constantes e env loading centralizados.
Importe daqui em vez de repetir load_dotenv() em cada módulo.
"""
import os
from dotenv import load_dotenv

_env_loaded = False


def load_env():
    """Idempotente: carrega .env uma única vez por processo."""
    global _env_loaded
    if _env_loaded:
        return
    load_dotenv()
    _script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_env = os.path.join(os.path.dirname(_script_dir), ".env")
    if os.path.exists(parent_env):
        load_dotenv(parent_env)
    _env_loaded = True


# Modelos Gemini padrão — ordem de preferência
DEFAULT_MODELS = ["gemini-3.1-flash-lite", "gemini-3.5-flash", "gemini-2.5-flash"]

# Limiar de silêncio absoluto: pico < 1e-6 → silêncio
SILENCE_THRESHOLD = 1e-6

# Marcadores de erro transitório da API Gemini
TRANSIENT_ERRORS = ("503", "429", "UNAVAILABLE", "RESOURCE_EXHAUSTED", "DeadlineExceeded", "timeout")


def get_fallback_models():
    """Retorna a lista de modelos, lendo GEMINI_MODELS do env se disponível."""
    load_env()
    model_env = os.environ.get("GEMINI_MODELS")
    if model_env:
        return [m.strip() for m in model_env.split(",") if m.strip()]
    return DEFAULT_MODELS.copy()
