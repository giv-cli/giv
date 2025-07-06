# Giv Documentation

Giv is a powerful tool for generating change logs from your Git history. It can be used with various Large Language Models (LLMs) to provide accurate and informative change logs.

## Supported LLMs

### OpenAI

To use OpenAI, set the `GIV_API_KEY` environment variable to your OpenAI API key. Then, run Giv with the desired model:

```bash
export GIV_API_KEY="your_openai_api_key"
giv --model-provider remote --api-model gpt-4
```

### Azure OpenAI

To use Azure OpenAI, set the `GIV_API_KEY` environment variable to your Azure OpenAI API key and specify the endpoint:

```bash
export GIV_API_KEY="your_azure_openai_api_key"
giv --model-provider remote --api-model gpt-4 \
          --api-url "https://my-azure-openai.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2023-05-15"
```

### Hugging Face Inference

To use Hugging Face Inference, set the `GIV_API_KEY` environment variable to your Hugging Face API key and specify the model:

```bash
export GIV_API_KEY="your_huggingface_api_key"
giv --model-provider remote --api-model gpt2
```

### OpenRouter (Unified API)

To use OpenRouter, set the `GIV_API_KEY` environment variable to your OpenRouter API key:

```bash
export GIV_API_KEY="your_openrouter_api_key"
giv --model-provider remote --api-model openai/gpt-4o
```

### Local Ollama Models

If you do not force remote mode, Giv will default to a local Ollama model (default `qwen2.5-coder`). You can select any local model by name with `--model`. For example, to use a Llama model:

```bash
giv --model llama3
```

Or to use a local Qwen or GPT model:

```bash
giv --model qwen3
```

This runs the Ollama CLI under the hood to summarize your Git history. (If you omit `--model`, it uses the default local model.)

## Environment Variables and Configuration

- You can set API keys and URLs via environment variables (`GIV_API_KEY`, `GIV_API_URL`, `GIV_API_MODEL`).
- Alternatively, use a `.env` file in your project root, or specify a config file with `--config-file <path>`.
- Example `.env`:

  ```env
  GIV_API_KEY=your_api_key
  GIV_API_URL=https://api.example.com/v1/chat/completions
  GIV_API_MODEL=gpt-4
  ```

## Integration Examples

Giv can be used in scripts or build pipelines just like any CLI tool. For example, add an npm script to generate the changelog:

```json
"scripts": {
  "changelog": "giv --staged"
}
```

Now running `npm run changelog` will invoke Giv on all staged changes. You can also call Giv programmatically. For instance, in Node.js:

```js
const { execSync } = require('child_process');
const output = execSync('giv --current');
console.log(output.toString());
```

Each of these examples is a normal bash command; the key is to have your API environment variables (or a `.env` file via `--config-file`) set so Giv can authenticate with the chosen LLM provider.
