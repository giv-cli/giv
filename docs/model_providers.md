# AI Model Providers

Giv supports various AI model providers for generating commit messages, changelogs, summaries, and other content. You can configure providers using the `giv config` command or environment variables.

## Configuration

Use the `giv config` command to set up your AI provider:

```bash
# Configure API settings
giv config api.url "https://api.openai.com/v1/chat/completions"
giv config api.model "gpt-4o-mini"
giv config api.key "your_api_key_here"
```

## Supported Providers

### OpenAI

To use OpenAI models, configure the following:

```bash
giv config api.url "https://api.openai.com/v1/chat/completions"
giv config api.model "gpt-4o-mini"  # or gpt-4o, gpt-3.5-turbo
giv config api.key "your_openai_api_key"
```

### Azure OpenAI

For Azure OpenAI, use your Azure endpoint URL:

```bash
giv config api.url "https://your-resource.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview"
giv config api.model "gpt-4"
giv config api.key "your_azure_openai_api_key"
```

### Groq

To use Groq's fast inference service:

```bash
giv config api.url "https://api.groq.com/openai/v1/chat/completions"
giv config api.model "llama-3.1-70b-versatile"  # or mixtral-8x7b-32768
giv config api.key "your_groq_api_key"
```

### Local Ollama Models

For local inference with Ollama (default configuration):

```bash
giv config api.url "http://localhost:11434/v1/chat/completions"
giv config api.model "devstral"  # or qwen2.5-coder, llama3.1, etc.
giv config api.key "ollama"  # any value works for local
```

### OpenRouter (Unified API)

To use OpenRouter for access to multiple models:

```bash
giv config api.url "https://openrouter.ai/api/v1/chat/completions"
giv config api.model "openai/gpt-4o-mini"  # or anthropic/claude-3-sonnet
giv config api.key "your_openrouter_api_key"
```

## Command-Line Overrides

You can override configured settings for individual commands:

```bash
# Use a different model for one command
giv changelog --api-model gpt-4o

# Use a different provider temporarily
giv summary --api-url "https://api.groq.com/openai/v1/chat/completions" \
            --api-model "llama-3.1-70b-versatile" \
            --api-key "your_groq_key"

# Use local Ollama model temporarily
giv message --api-url "http://localhost:11434/v1/chat/completions" \
            --api-model "qwen2.5-coder"
```

## Environment Variables

You can also set configuration via environment variables:

```bash
export GIV_API_URL="https://api.openai.com/v1/chat/completions"
export GIV_API_MODEL="gpt-4o-mini"
export GIV_API_KEY="your_api_key"

giv changelog  # Uses environment variables
```

Configuration hierarchy (highest to lowest priority):
1. Command-line arguments (`--api-model`, `--api-url`, etc.)
2. Environment variables (`GIV_API_*`)
3. `.giv/config` file
4. Default values

## Testing Your Configuration

To verify your configuration is working:

```bash
# List current configuration
giv config list

# Test with a simple message generation
giv message --dry-run --verbose
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
