# Local LLM Recommendations For Mac mini M4 16GB

## Baseline

Environment:

- Mac mini with Apple M4, not M4 Pro
- 16GB unified memory
- 120GB/s memory bandwidth
- Ollama and Qwen are assumed as the default runtime/model line

Operating rule:

- Prefer 1B-4B models
- Use Q4_K_M or QAT Q4 first
- Treat 7B-8B Q4 as the upper bound for single-model runs
- Avoid 12B+ as a regular development model on 16GB
- Start context length at 8K; use 16K only when needed
- Do not keep multiple large models resident at once

## Final Shortlist

### 1. IBM Granite 4.1 3B GGUF

Repository:

https://huggingface.co/ibm-granite/granite-4.1-3b-GGUF

Recommended quant:

```bash
ollama run hf.co/ibm-granite/granite-4.1-3b-GGUF:Q4_K_M
```

Recommended role:

- RAG answer generation
- structured extraction
- JSON output
- tool/function calling tests
- code explanation and small code edits

Why:

Granite overlaps less with Qwen than another general chat model. Use Qwen for
main reasoning/chat and Granite for structured PMS workflows.

### 2. Kakao Kanana 1.5 2.1B Instruct

Official model:

https://huggingface.co/kakaocorp/kanana-1.5-2.1b-instruct-2505

Community GGUF:

https://huggingface.co/tensorblock/kakaocorp_kanana-1.5-2.1b-instruct-2505-GGUF

Recommended quant:

```bash
ollama run hf.co/tensorblock/kakaocorp_kanana-1.5-2.1b-instruct-2505-GGUF:Q4_K_M
```

Recommended role:

- Korean lightweight assistant
- intent routing
- classification
- keyword extraction
- short meeting summaries

Note:

The original model is Kakao's model, but the GGUF repository above is a
community conversion. Pin it only after local tests.

### 3. Google Gemma 3 4B IT QAT

Official model:

https://huggingface.co/google/gemma-3-4b-it

GGUF quant:

https://huggingface.co/bartowski/google_gemma-3-4b-it-qat-GGUF

Recommended command:

```bash
ollama run hf.co/bartowski/google_gemma-3-4b-it-qat-GGUF:Q4_0
```

If image input is required, prefer Ollama's native Gemma package:

```bash
ollama run gemma3:4b
```

Recommended role:

- alternative model family for comparison against Qwen
- lightweight multimodal experiment
- summarization/reasoning baseline

### 4. Mistral Ministral 3 3B

Repository:

https://huggingface.co/mistralai/Ministral-3-3B-Reasoning-2512-GGUF

Recommended role:

- JSON and tool-calling experiments
- reasoning/coding/STEM tests
- agent workflow comparison

Note:

Use this as a Granite alternative, not together with every other model. On a
16GB Mac mini, the model zoo must stay small.

### 5. LiquidAI LFM2.5 1.2B Instruct

Repository:

https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF

Recommended command:

```bash
ollama run hf.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF:Q4_K_M
```

Recommended role:

- ultra-light classifier
- routing
- extraction
- quick local smoke tests

Note:

Use it when speed and memory are more important than answer depth.

## Watchlist / Research Only

### LG EXAONE 4.0 1.2B GGUF

Repository:

https://huggingface.co/LGAI-EXAONE/EXAONE-4.0-1.2B-GGUF

Potential role:

- Korean on-device experiments
- lightweight classification
- short summary

Reason for caution:

EXAONE is interesting for Korean work, but confirm runtime and license
constraints before making it a project dependency.

## Recommended Install Order

Start with three models:

```bash
# Main additional structured/RAG model
ollama run hf.co/ibm-granite/granite-4.1-3b-GGUF:Q4_K_M

# Korean lightweight model
ollama run hf.co/tensorblock/kakaocorp_kanana-1.5-2.1b-instruct-2505-GGUF:Q4_K_M

# Optional alternate family / multimodal experiment
ollama run gemma3:4b
```

Then test each model with the same PMS prompts:

1. Meeting summary JSON
2. Action item extraction
3. Decision extraction
4. Korean classification
5. RAG answer grounded in project notes
6. Accounting draft guardrail response

## Model Assignment For This Project

| Task | Primary | Backup |
|---|---|---|
| Main Korean reasoning | Qwen | Gemma 3 4B |
| Meeting JSON extraction | Granite 4.1 3B | Ministral 3 3B |
| Korean intent routing | Kanana 2.1B | LFM2.5 1.2B |
| RAG answer generation | Granite 4.1 3B | Qwen |
| Coding explanation | Granite 4.1 3B | Qwen |
| Image/screenshot experiment | Gemma 3 4B | external API |
| Accounting/cost draft | Qwen or Granite | rule engine must validate |
