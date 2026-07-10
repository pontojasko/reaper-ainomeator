README — Reaper AI Track Namer (Resumo para IAS)

Visão geral
-----------
Este repositório implementa uma solução leve para identificar automaticamente a fonte principal (instrumento) de cada faixa de áudio em um projeto do Reaper, usando o modelo Gemini (API Google GenAI). O objetivo é validar e operacionalizar a "parte de IA" (classificação de tracks) de forma segura, escalável para múltiplas faixas e integrada ao Reaper via ReaScript.

Público alvo: equipe IAS (análise de soluções, integração e governança de IA).

Principais objetivos
--------------------
- Validar o prompt e o vocabulário (vocabulario fechado de categorias) com testes locais antes de integrar ao Reaper.
- Minimizar custo e latência: enviar apenas trechos curtos e representativos (mono, 16kHz) ao modelo.
- Permitir execução em lote (paralelismo controlado por threads) e integração transparente com Reaper.

Componentes e responsabilidade de cada arquivo
----------------------------------------------
- reaper_ai_track_namer.lua
  - ReaScript que roda dentro do Reaper (FASE 4).
  - Varre tracks, constrói um manifest (TSV leve), chama o processador Python e aplica nome, cor e ícone nas tracks.

- batch_rename.py
  - Processador em lote chamado pelo .lua.
  - Lê o manifest (idx<TAB>arquivo<TAB>start<TAB>dur) e cria um conjunto de tarefas paralelas com ThreadPoolExecutor.
  - Para cada job: extrai trecho representativo, gera versão leve, chama a API e escreve o resultado num TSV (idx<TAB>status<TAB>categoria<TAB>instrumento<TAB>confianca<TAB>erro).

- classify_track.py
  - Lógica principal de classificação via Gemini.
  - fluxo: extrair trecho -> downmix & resample -> enviar bytes inline ao Gemini -> parsear JSON de resposta.
  - Contém PROMPT (controlado) e lista de MODELOS_FALLBACK para tolerância a falhas (503/429 etc.).

- audio_utils.py
  - Funções utilitárias locais (numpy + soundfile): leitura segura, extração de janela de maior energia (RMS), conversão para mono+16kHz.
  - Tenta conversão com ffmpeg caso soundfile não leia o formato.

- test_batch.py
  - Script de validação: roda várias amostras com gabarito e calcula acurácia antes de integrar ao Reaper.

- requirements.txt
  - Dependências: google-genai, python-dotenv, numpy, soundfile.

- setup.bat
  - Cria venv, instala dependências e gera .env (onde colocar GEMINI_API_KEY).

Fluxo de dados e arquitetura (texto/assíncrono)
-----------------------------------------------
1. Reaper (usuário) roda o ReaScript (reaper_ai_track_namer.lua).
2. O script inspeciona tracks e escreve um manifest TSV leve: cada linha -> idx\tpath\tstart\tduration.
3. O .lua chama: python batch_rename.py manifest.tsv resultado.tsv --workers N
4. batch_rename.py lê manifest, cria um ThreadPoolExecutor e para cada entrada:
   - chama audio_utils.extract_best_segment(...) dentro da janela indicada (se informada);
   - chama audio_utils.downmix_resample(...) para gerar WAV mono/16kHz;
   - envia bytes inline ao Gemini via classify_audio_bytes (classify_track.py);
   - grava resultado (ok/erro, categoria, instrumento, confianca) em result.tsv.
5. O .lua lê result.tsv e aplica nome, cor e ícone nas tracks do projeto.

Observações importantes sobre performance e custo
------------------------------------------------
- Só é enviado ao modelo um trecho curto (padrão 8s), o que reduz significativamente custo e latência.
- Threads (ThreadPoolExecutor) são suficientes porque as chamadas são I/O-bound (rede/API).
- Há fallback de modelos (MODELOS_FALLBACK) e backoff/retries para erros transientes (503, 429).
- Ajuste `--workers` no batch para controlar paralelismo — cuidado com rate limits da conta Gemini.

Segurança e governança de IA (relevante para IAS)
-------------------------------------------------
- Vocabulário fechado: categorias permitidas são controladas (vocal, guitarra, baixo, bateria, teclado, synth, sopro, cordas, outro) para padronizar saída e reduzir deriva de linguagem.
- Prompt formatado para retornar APENAS JSON válido. O parsing JSON no Python é estrito; respostas inválidas levam a fallback para outro modelo.
- A chave GEMINI_API_KEY é lida de .env e nunca versionada — instruções no setup.bat.
- Dados de áudio permanecem locais; somente trechos compactados (mono/16kHz) são enviados.
- Logs e manifest/result temporários são gravados em pasta temporária do Reaper (reaper-ai-namer_tmp) — revisar política de retenção e remoção se necessário.

Pontos de atenção / riscos conhecidos
-----------------------------------
- Modelos Gemini podem ser descontinuados ou sofrer alteração de nomes: o código já possui MODELOS_FALLBACK e comentário instruindo a atualizar nomes caso 404.
- Erros 503/429 são comuns; o pipeline tenta fallback, mas altas taxas de requisição podem levar a falhas. Recomendação: limitar workers e implementar retry exponencial global se necessário.
- Respostas não-JSON do modelo interrompem parse; o sistema tenta o próximo modelo em fallback.
- ffmpeg é invocado se soundfile não conseguir ler um formato; garantir ffmpeg disponível em máquinas que rodarem em ambiente Windows sem venv.

Como rodar para validar (passos rápidos)
---------------------------------------
1. Colocar os arquivos do repositório em uma pasta no Windows (ex: C:\reaper-ai-namer).
2. Rodar setup.bat (duplo clique) — cria venv, instala dependências e cria .env (editar com GEMINI_API_KEY).
3. Teste single: arrastar um WAV para test_single.bat ou `test_single.bat "C:\caminho\arquivo.wav"`.
4. Teste lote: preencher GABARITO em test_batch.py e rodar test_batch.bat para medir acurácia.
5. Se satisfeito, carregar reaper_ai_track_namer.lua no Reaper e rodar a ação (ver README.md para detalhes).

Formatos e contratos (manifests/resultados)
-------------------------------------------
- Manifest (entrada para batch_rename.py):
  idx<TAB>caminho_do_audio<TAB>inicio_segundos<TAB>duracao_segundos

- Resultado (saida de batch_rename.py lida pelo Lua):
  idx<TAB>status<TAB>categoria<TAB>instrumento<TAB>confianca<TAB>erro
  - status = "ok" ou "erro". Em erro, campos categoria/instrumento/confianca ficam vazios e `erro` tem mensagem limpa (sem tabs/newlines).

Checklist de auditoria para IAS
-------------------------------
- [ ] Verificar tratamento de chaves e ciclo de vida da GEMINI_API_KEY (rota de rotação/expiração).
- [ ] Definir política de retenção para reaper-ai-namer_tmp e logs contendo paths locais.
- [ ] Registrar taxa de solicitações (metrics) e configurar limites para evitar 429.
- [ ] Testes de robustez: simular latência/erros 503 e validar comportamento do fallback.
- [ ] Revisar prompt e exemplos de saída com especialistas de domínio para reduzir vieses e ambiguidade semântica.

Sugestões de melhorias (próximos passos)
----------------------------------------
- Implementar um contador central de rate-limit adaptativo para reduzir workers dinamicamente ao detectar 429s/503s.
- Adicionar métricas (Prometheus/Logs estruturados) para monitorar latência, erros por modelo e acurácia por categoria.
- Pipeline de testes automatizados (CI) que roda test_batch.py com um conjunto de amostras de validação antes de liberar atualizações.
- Opcional: adicionar assinatura/registro de hashes dos trechos enviados para auditoria (sem incluir áudio em si), para rastreabilidade.

Contato/Referências
-------------------
- Repositório local: pasta raiz do projeto.
- Arquivo de referência: README.md (documentação de uso passo-a-passo e debug técnico).

Anexo: lista resumida de arquivos
--------------------------------
- reaper_ai_track_namer.lua — ReaScript (integração Reaper)
- batch_rename.py — processador paralelo (chama a IA)
- classify_track.py — lógica de chamada ao Gemini, prompt e parsing
- audio_utils.py — extração de trecho + downmix/resample
- test_batch.py — validação com gabarito
- requirements.txt, setup.bat, .env (gerado), samples/ (dados de teste)

---
Documento gerado automaticamente a partir da inspeção do código fonte no repositório local.
