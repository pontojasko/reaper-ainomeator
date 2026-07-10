# Reaper AI Track Namer — Fase 1 (validação da IA, sem Reaper)

A ideia é validar a parte de IA **completamente isolada do Reaper** antes de
escrever uma linha de ReaScript. É muito mais rápido iterar num terminal do
que dentro do editor de scripts do Reaper (que trava a UI, tem console
limitado, e cada teste exige alt-tab pra DAW).

## Passo 0 — Pré-requisitos

- Python 3.9+ instalado no Windows e disponível no PATH
  (teste abrindo o `cmd` e rodando `python --version`)
- Uma API key do Gemini, gratuita: https://aistudio.google.com/apikey

## Passo 1 — Setup

1. Extraia esta pasta em algum lugar (ex: `C:\reaper-ai-namer`)
2. Dê duplo clique em `setup.bat`
   - Isso cria um `venv`, instala as dependências, e gera um arquivo `.env`
3. Abra o arquivo `.env` (bloco de notas mesmo) e cole sua chave real:
   ```
   GEMINI_API_KEY=AIzaSy...sua_chave_real
   ```

## Passo 2 — Teste com UM áudio (validação rápida)

Pegue qualquer arquivo de áudio curto que você tenha (uma faixa de guitarra,
um vocal, o que for — não precisa ser do Reaper ainda, pode ser qualquer wav/mp3).

Duas formas:
- Arraste o arquivo em cima de `test_single.bat`
- Ou pelo terminal: `test_single.bat "C:\caminho\guitarra.wav"`

Você deve ver um JSON assim (agora com info do trecho analisado):
```json
{
  "instrument": "guitarra base distorcida",
  "category": "guitarra",
  "confidence": 0.9,
  "notes": "audio limpo, sem ruido de fundo",
  "_segment_start_seconds": 14.5,
  "_segment_duration_seconds": 8.0
}
```

**Como funciona o corte de trecho:** antes de mandar qualquer coisa pro
Gemini, o script (`audio_utils.py`) analisa a energia do áudio localmente
(sem IA, é só matemática com numpy) e acha a janela de 8 segundos (ajustável
com `--segment-seconds`) com mais som — evitando silêncio no início/fim ou
trechos onde o instrumento não está tocando. Só esse trechinho é enviado
pra API. Isso deixa a análise bem mais rápida e barata em stems longos.

Se quiser comparar com o arquivo inteiro (só pra debug), use `--full`:
```
python classify_track.py teste.wav --full
```

Se quiser conferir exatamente qual pedaço de áudio foi analisado, use
`--keep-segment` — o caminho do wav temporário aparece no resultado
(`_segment_file`) e você pode abrir ele pra ouvir.

> **Nota sobre modelos:** a Google descontinua modelos do Gemini com frequência.
> O script usa `gemini-3.1-flash-lite` como modelo **principal** por padrão —
> é o mais rápido/barato da família, o que importa bastante quando o Reaper
> vai mandar dezenas de faixas em paralelo (Fase 4). Se no futuro aparecer
> erro `404 NOT_FOUND` dizendo que o modelo não existe mais, troque o nome
> no topo de `classify_track.py` (lista `MODELOS_FALLBACK`) — confira o nome
> certo em https://ai.google.dev/gemini-api/docs/models.

> **Sobre erros 503 (sobrecarga):** é um problema conhecido e recorrente do
> lado do Google — não é nada errado no seu setup. Por isso o script já vem
> com fallback automático: tenta `gemini-3.1-flash-lite` 2x, se continuar
> sobrecarregado cai pro `gemini-3.5-flash`, e por fim `gemini-2.5-flash`.
> Cada modelo roda em cluster de capacidade separado no Google, então um
> estar sobrecarregado não significa que os outros estejam. O resultado
> final traz `_model_usado` mostrando qual modelo respondeu.
> Pra customizar a ordem: `python classify_track.py teste.wav --models gemini-3.5-flash,gemini-3.1-flash-lite`

> **Sobre velocidade/formato do áudio enviado:** antes de mandar pro Gemini,
> o trecho de 8s é convertido pra **mono, 16kHz** (função `downmix_resample`
> em `audio_utils.py`) e enviado como bytes inline no próprio request (sem
> upload de arquivo + espera de processamento). Isso deixa cada chamada bem
> mais leve e rápida — importante multiplicado por várias faixas em paralelo.

**Se der erro aqui**, é 100% um problema de API/ambiente (chave errada, sem
internet, formato de arquivo não suportado) — resolva isso ANTES de ir pro
Reaper, porque lá vai ser muito mais difícil de diagnosticar.

Erros comuns:
| Erro | Causa provável |
|---|---|
| `GEMINI_API_KEY nao encontrada` | esqueceu de editar o `.env` |
| `403` ou `PERMISSION_DENIED` | chave inválida ou API não habilitada no projeto Google |
| `arquivo nao encontrado` | caminho com aspas erradas ou espaço não escapado |
| resposta não é JSON válido | raro, mas pode acontecer — o script já mostra o `raw_response` pra você ver o que veio |

## Passo 3 — Teste em lote (medir precisão antes de confiar)

Isso é o passo que mais importa antes de automatizar de verdade: você quer
saber se a IA acerta consistentemente, não só numa amostra.

1. Coloque uns 5-10 arquivos de áudio curtos (5-15s, um instrumento por
   arquivo) na pasta `samples/`
2. Abra `test_batch.py` e edite o dicionário `GABARITO` no topo do arquivo,
   colocando o nome de cada arquivo e a categoria correta esperada
3. Rode `test_batch.bat`
4. Veja o placar final (X/Y acertos) e quais divergiram

Se a acurácia estiver ruim (tipo confundindo baixo com guitarra), o ajuste
é no `PROMPT` dentro de `classify_track.py` — não precisa mexer em mais nada.
Iterar no prompt aqui é rápido: edita, roda `test_batch.bat` de novo, compara.

## Passo 4 — integração com o Reaper (`reaper_ai_track_namer.lua`)

Depois que o Passo 3 estiver com acurácia que você confia, é hora de usar
o script de verdade dentro do Reaper: `reaper_ai_track_namer.lua`.

### Como funciona

1. O ReaScript escaneia as tracks do projeto — **por padrão TODAS**, não
   só as selecionadas (dá pra restringir às selecionadas na caixa de
   diálogo de opções, se quiser).
2. Pra cada track com áudio, acha o item mais representativo (o de maior
   duração usada) e pega o caminho do arquivo-fonte + a janela (início/
   duração) que aquele item realmente ocupa nesse arquivo.
3. Escreve um **manifest** em texto puro, tab-separated (nada de JSON/XML —
   é o formato mais leve possível pra essa troca de dados), com uma linha
   por track: `idx  caminho_do_audio  inicio_segundos  duracao_segundos`.
4. Chama `batch_rename.py`, que processa **todas as tracks em paralelo**
   usando `ThreadPoolExecutor` (as chamadas de API são I/O-bound — o
   gargalo é rede, não CPU — então threads bastam, sem necessidade de
   multiprocessing). Cada thread corta o trecho de maior energia dentro da
   janela do item, converte pra mono/16kHz (bem leve) e manda pro Gemini
   (`gemini-3.1-flash-lite` por padrão) como bytes inline.
5. O resultado volta num arquivo igualmente leve (tab-separated), e o
   ReaScript aplica em cada track: **nome** (o instrumento identificado),
   **cor** (paleta fixa por categoria) e **ícone** (procurado
   automaticamente entre os ícones de faixa que já vêm com o Reaper, em
   `Data/track_icons`, por palavra-chave da categoria).

Tracks MIDI, vazias ou sem fonte de áudio são identificadas e ignoradas
automaticamente (não fazem chamada de API, não dá erro).

### Instalação

1. Confirme que já rodou `setup.bat` nesta pasta e configurou o `.env`
   com sua `GEMINI_API_KEY` (Passos 0–1 acima).
2. No Reaper: `Actions > Show action list... > New action... > Load
   ReaScript...` e selecione `reaper_ai_track_namer.lua` (nesta mesma
   pasta — o script descobre sozinho onde estão o Python do venv e o
   `batch_rename.py`, então **não mova os arquivos separadamente**).
3. Rode a ação sempre que quiser (dá pra atribuir um atalho de teclado
   nessa mesma tela do Action List).

### Ao rodar

Aparece uma caixa de diálogo com 3 opções (todas com valor padrão já
preenchido):
- **Apenas faixas selecionadas (0/1):** `0` = todas as tracks do projeto
  (padrão), `1` = só as selecionadas.
- **Segundos de trecho analisado:** `8` por padrão (igual ao Passo 2/3).
- **Threads em paralelo:** `5` por padrão. Pode aumentar se tiver muitas
  faixas e quiser mais velocidade, mas cuidado com rate limit da API
  (free tier do Gemini costuma limitar requisições por minuto — se
  começar a ver muitos erros `429`, reduza esse número).

Depois de confirmar, o Reaper mostra o console de scripts com o progresso
de cada track (o mesmo log que o `batch_rename.py` gera) e, ao final, um
resumo de quantas faixas foram atualizadas com sucesso.

### Debug

- Todo log do processo Python aparece no console do Reaper (junto com o
  log do próprio ReaScript), então dá pra ver exatamente onde algo quebrou.
- Os arquivos temporários (manifest, resultado, log) ficam salvos em
  `<pasta de recursos do Reaper>/reaper-ai-namer_tmp/` — úteis se quiser
  conferir manualmente o que foi mandado/recebido. Pode apagar essa pasta
  a qualquer momento, ela é recriada a cada execução.
- Se a caixa de erro disser que não gerou resultado, os motivos mais
  comuns são: `setup.bat` não foi rodado nesta pasta (falta `venv`/`.env`),
  `GEMINI_API_KEY` não configurada, ou Python não encontrado no PATH (nesse
  caso o script tenta usar o `venv` local antes de cair pro `python`/`python3`
  do sistema).

## Estrutura de arquivos

```
reaper-ai-namer/
├── reaper_ai_track_namer.lua  # FASE 4: ReaScript que roda dentro do Reaper
├── batch_rename.py             # FASE 4: classifica várias tracks em paralelo (chamado pelo .lua)
├── classify_track.py           # lógica principal (chama o Gemini), usado pelo batch_rename.py e testes
├── audio_utils.py               # corte por energia + downsample leve (mono/16kHz) pra API
├── test_batch.py                 # roda vários samples e mede acurácia
├── requirements.txt
├── setup.bat                     # roda uma vez, prepara tudo
├── test_single.bat               # testa um arquivo de áudio
├── test_batch.bat                # testa a pasta samples/ inteira
├── .env                          # sua chave (criado pelo setup.bat, não versionar)
└── samples/                       # seus áudios de teste (você adiciona)
```
