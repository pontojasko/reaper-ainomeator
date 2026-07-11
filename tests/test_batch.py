"""
test_batch.py

FASE 1B: depois que classify_track.py funciona num arquivo só, use
este script pra rodar contra uma pastinha de samples COM GABARITO
conhecido, e ver a taxa de acerto antes de confiar no pipeline.

Como usar:
1. Coloque uns 5-10 arquivos de audio curtos (5-15s cada) na pasta samples/
   -- pode ser trechos que voce corta de faixas suas mesmo, tanto faz.
2. Edite o dicionario GABARITO abaixo com o nome do arquivo -> categoria esperada
3. Rode: python test_batch.py

Isso evita descobrir que o prompt esta ruim so depois de integrar com o Reaper.
"""

import os
import sys
import json
from dotenv import load_dotenv
from google import genai

# Adiciona a pasta src ao caminho de busca do Python
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(_SCRIPT_DIR, "..", "src")))

from classify_track import classify_track, CATEGORIAS_VALIDAS

SAMPLES_DIR = os.path.join(_SCRIPT_DIR, "samples")

# Preencha com os nomes dos seus arquivos de teste e a categoria correta esperada.
# Exemplo:
GABARITO = {
    "vocal_teste.wav": "vocal",
    "guitarra_teste.wav": "guitarra",
    "baixo_teste.wav": "baixo",
    "bateria_teste.wav": "bateria",
}


def main():
    load_dotenv()
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("ERRO: GEMINI_API_KEY nao definida (veja README.md)")
        return

    client = genai.Client(api_key=api_key)

    if not os.path.isdir(SAMPLES_DIR):
        print(f"Pasta '{SAMPLES_DIR}' nao existe. Crie e coloque uns audios de teste nela.")
        return

    acertos = 0
    total = 0
    resultados = []

    for filename, esperado in GABARITO.items():
        path = os.path.join(SAMPLES_DIR, filename)
        if not os.path.isfile(path):
            print(f"[PULADO] {filename} nao encontrado em {SAMPLES_DIR}/")
            continue

        total += 1
        print(f"\nTestando: {filename} (esperado: {esperado})")
        result = classify_track(client, path)

        if "error" in result:
            print(f"  ERRO: {result['error']}")
            resultados.append((filename, esperado, "ERRO", result.get("error")))
            continue

        obtido = result.get("category")
        confianca = result.get("confidence")
        acertou = obtido == esperado
        acertos += acertou

        status = "OK" if acertou else "DIVERGIU"
        print(f"  {status} -> obtido: {obtido} (confianca {confianca}) | instrumento: {result.get('instrument')}")
        resultados.append((filename, esperado, obtido, confianca))

    print("\n" + "=" * 50)
    print(f"RESULTADO: {acertos}/{total} acertos")
    print("=" * 50)
    for filename, esperado, obtido, extra in resultados:
        marca = "✓" if esperado == obtido else "✗"
        print(f"  {marca} {filename}: esperado={esperado} obtido={obtido}")


if __name__ == "__main__":
    main()
