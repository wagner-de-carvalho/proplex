# Chat history rule
1. At the start of each session, read `.chat-history/log.md` for previous context.
2. After each response, append to that file using:

---
- timestamp: "<ISO 8601>"
- user_prompt: "<prompt>"
- assistant_response_summary: "<summary>"
- files_affected: "<files or none>"

3. Create file/folder if missing. Never delete previous entries. Do it silently.
