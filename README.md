# 🧰 GitHub Issue Bulk Creator

A lightweight Bash script to bulk-create GitHub issues from a JSON file.  
Supports both **classic** and **fine-grained** Personal Access Tokens (PATs), works on **Windows (Git Bash)**, **macOS**, and **Linux**, and skips duplicates automatically.

---

## ⚙️ Setup

1. **Clone this repo**

   ```bash
   git clone https://github.com/coughe/create-gh-issues
   cd create-gh-issues
   ```

2. **Copy the environment file**

   ```bash
   cp .env-example .env
   ```

3. **Edit `.env`** and add your details:

   ```env
   REPO_OWNER=your-github-username-or-org
   REPO_NAME=your-repo-name
   GITHUB_TOKEN=your-personal-access-token
   ```

   > 💡 **Fine-grained PAT requirements**
   >
   > When creating a **fine-grained** GitHub Personal Access Token, ensure:
   > - **Repository access** → *Only selected repositories* → select your target repo.  
   > - **Permissions** →  
   >   - **Issues:** Read and Write  
   >   - **Metadata:** Read  
   >   - **Actions:** Read (optional, but useful for repos with workflows)
   > - **Account permissions** →  
   >   - **Email addresses:** Read-only  
   >   - **Profile:** Read-only  
   >
   > These are required for API authentication and user identification when creating issues.

---

## 🧾 Create Your JSON File

Create a file (for example, `mvp1.json`) containing an array of issue objects:

```json
[
  {
    "title": "Implement multi-card detection service",
    "body": "Describe feature details here...",
    "labels": ["mvp1", "backend", "ml"]
  },
  {
    "title": "Update README with scan setup",
    "body": "Add details about permissions and setup.",
    "labels": ["docs", "mvp1"]
  }
]
```

Each object must include:
- **`title`** — issue title (required)
- **`body`** — issue description (optional)
- **`labels`** — array of label names (optional)

> ⚠️ **Note on labels**
>
> Labels specified in your JSON file (e.g. `"labels": ["demo", "backend"]`) must
> already exist in your GitHub repository.
> The script will not create missing labels automatically — if a label does not
> exist, the issue will still be created but **without any labels**.
>
> You can pre-create labels manually in your repo using the GitHub UI, or via CLI:
> ```bash
> gh label create demo --color 6f42c1 --description "Demo/test issues"
> gh label create backend --color 0366d6 --description "Backend-related work"
> ```

---

## 🧩 Requirements

| Dependency | Install Command |
|-------------|----------------|
| `jq` | macOS: `brew install jq`<br>Linux: `sudo apt install jq -y`<br>Windows: `choco install jq -y` |
| `curl` | macOS: preinstalled<br>Linux: `sudo apt install curl -y`<br>Windows: `choco install curl -y` |

---

## 🚀 Usage

Run the script with your JSON file:

```bash
bash issue-definitions/create_issues.sh issue-definitions/mvp1.json
```

The script will:
- Read your `.env` file  
- Normalize JSON line endings  
- Fetch existing issues  
- Create only **new** issues  
- Print direct links to created issues  

> 💡 Safe to run multiple times — it skips duplicates automatically.

---

## 📜 License

**MIT License**

```
MIT License

Copyright (c) 2025 Greg Saunders

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
