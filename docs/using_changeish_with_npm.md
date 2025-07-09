# Supercharge Your npm Project Changelog with AI: Automate Releases Using giv

Keeping a changelog up to date is essential for any project, but it’s often tedious and easy to neglect. What if you could automate beautiful, structured changelogs using AI—right from your npm workflow? Enter [giv](https://github.com/giv-cli/giv): an open-source Bash tool that summarizes your Git history into clean, Markdown changelogs using local or remote AI models.

In this post, I’ll show you how to integrate giv into your npm-based project, customize it for your workflow, and never stress about changelogs again.

---

## Why giv?

- ✨ **Automated, human-readable changelogs**: Summarizes your Git commit history into Markdown.
- 🤖 **AI-powered**: Works with local Ollama models or remote OpenAI-compatible APIs.
- 🛠️ **Customizable**: Easily specify your changelog path, prompt template, or focus on TODOs.
- 🚀 **Easy install & updates**: One-line install, minimal dependencies.

---

## Quick Install

First, install giv globally:

```bash
curl -fsSL https://raw.githubusercontent.com/giv-cli/giv/main/install.sh | sh
```

---

## Add giv to Your npm Scripts

To make changish part of your workflow, add a script to your `package.json`. For example:

```json
{
  "scripts": {
    "changelog": "giv --changelog-file ./CHANGELOG.md"
  }
}
```

Now, you can run:

```bash
npm run changelog
```

This will generate or update your CHANGELOG.md using your latest Git history.

---

## Customizing for Your Project

giv is highly configurable. Here are some ways to tailor it to your needs:

### 1. Specify a Custom TODO Pattern

If you track TODOs in markdown files, you can focus the changelog on those changes:

```json
{
  "scripts": {
    "changelog": "giv --short-diff"
  }
}
```

Or, for more advanced filtering (coming soon), you’ll be able to use custom include/exclude patterns.

### 2. Use a Custom Changelog Path

Want to keep your changelog somewhere else? Just set the path:

```json
{
  "scripts": {
    "changelog": "giv --changelog-file ./docs/CHANGELOG.md"
  }
}
```

### 3. Use a Custom Prompt Template

You can provide your own prompt template for the AI model:

```json
{
  "scripts": {
    "changelog": "giv --prompt-template ./docs/prompt_template.md"
  }
}
```

### 4. Only Show Uncommitted or Staged Changes

Generate a changelog for just your current work:

```json
{
  "scripts": {
    "changelog": "giv --current"
  }
}
```

Or for staged changes:

```json
{
  "scripts": {
    "changelog": "giv --staged"
  }
}
```

---

## Pro Tips

- You can set environment variables (like `GIV_MODEL` or `GIV_API_KEY`) in a .env file for more advanced configuration.
- giv works great in CI/CD pipelines—just call your npm script as part of your release process.

---

## Try It Out!

Automate your changelog, impress your users, and streamline your releases. Add giv to your npm project today and let AI do the heavy lifting.

👉 [Get giv on GitHub](https://github.com/giv-cli/giv)

---

If you found this helpful, leave a ⭐️ on the repo and share your experience in the comments!

