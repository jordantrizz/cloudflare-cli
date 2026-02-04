# AGENTS.md
## Development Notes
* Always provide a short single line git commit message to copy and paste after code changes.
* The git commit message should be formatted as https://www.conventionalcommits.org/en/v1.0.0/ 
* The commit contains the following structural elements, to communicate intent to the consumers of your library:
fix: a commit of the type fix patches a bug in your codebase (this correlates with PATCH in Semantic Versioning).
feat: a commit of the type feat introduces a new feature to the codebase (this correlates with MINOR in Semantic Versioning).
BREAKING CHANGE: a commit that has a footer BREAKING CHANGE:, or appends a ! after the type/scope, introduces a breaking API change (correlating with MAJOR in Semantic Versioning). A BREAKING CHANGE can be part of commits of any type.
types other than fix: and feat: are allowed, for example @commitlint/config-conventional (based on the Angular convention) recommends build:, chore:, ci:, docs:, style:, refactor:, perf:, test:, and others.
footers other than BREAKING CHANGE: <description> may be provided and follow a convention similar to git trailer format.
Additional types are not mandated by the Conventional Commits specification, and have no implicit effect in Semantic Versioning (unless they include a BREAKING CHANGE). A scope may be provided to a commit’s type, to provide additional contextual information and is contained within parenthesis, e.g., feat(parser): add ability to parse arrays.
* Functions should exist in cf-inc.sh or cf-inc-cf.sh as we want to keep cloudflare.sh clean

## Deprecated Functions
Don't use these functions anymore, they will be removed in future versions.
* findout_record
* json_decode 