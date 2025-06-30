# GitHub Copilot Instructions for docker-whisperX

* **Response Language:** `zh-TW 正體中文`

# Key Directives:

* Maintain the highest standard of quality in all deliverables by following best practices.
* All code comments and documentation must be written in **English** as per project conventions.
* Proactively consult both core documentation and conversation history to ensure accurate comprehension of all requirements.
* You are neither able to execute `docker`, use `podman` instead.
* When doing Git commit, use the conventional commit format for the title and a brief description in the body. Always commit with `--signoff` and explicitly specify the author on the command: `GitHub Copilot <bot@xn--jgy.tw>`. Write the commit in English.

---

# Project DevOps

This project uses GitHub for DevOps management.

Please use the #github-sudo tool to perform DevOps tasks.

***Highest-level restriction: All issue and PR operations are limited to repositories owned by jim60105 only!***

* **GitHub repo**: https://github.com/jim60105/docker-whisperX

* **Backlog & Bugs**: All backlogs and bugs must be managed on GitHub Issues.

  * Each issue represents a specific backlog plan / bug reports / enhancement requests.
  * Contains implementation or bug-fix guides from project foundation to deployment
  * Each issue(backlogs) includes complete technical design and implementation details
  * Each issue(bugs) includes problem description, reproduction steps, and proposed solutions
  * Serves as task queue for ongoing maintenance and improvements

## DevOps Flow

### Planning Stage

**If we are at planning stage you shouldn't start to implement anything!**
**Planning Stage is to create a detailed development plan and #create_issue on GitHub**

1. **Issue Creation**: #create_issue Create a new issue for each backlog item or bug report. Write the issue description plans in 正體中文, but use English for example code comments and CLI responses. The plan should be very detailed (try your best!). Please write that enables anyone to complete the work successfully.
2. **Prompt User**: Show the issue number and link to the user, and ask them if they want to made any changes to the issue description. If they do, you can edit the issue description using #update_issue .

### Implementation Stage

**Only start to implement stage when user prompt you to do so!**
**Implementation Stage is to implement the plan step by step, following the instructions provided in the issue and submit a work report PR at last**

1. **Check Current Situation**: #runCommands `git status` Check the current status of the Git repository to ensure you are aware of any uncommitted changes or issues before proceeding with any operations. If you are not on the master branch, you may still in the half implementation state, get the git logs between the current branch and master branch to see what you have done so far. If you are on the master branch, you seems to be in the clean state, you can start to get a new issue to work on.
2. **Get Issue Lists**: #list_issues Get the list of issues to see all backlogs and bugs. Find the issue that user ask you to work on or the one you are currently working on. If you are not sure which issue to choose, you can list all of them and ask user to assign you an issue.
3. **Get Issue Details**: #get_issue Get the details of the issue to understand the requirements and implementation plan. Its content will include very comprehensive and detailed technical designs and implementation details. Therefore, you must read the content carefully and must not skip this step before starting the implementation.
4. **Get Issue Comments**: #get_issue_comments Read the comments in the issue to understand the context and any additional requirements or discussions that have taken place. Please read it to determine whether this issue has been completed, whether further implementation is needed, or if there are still problems that need to be fixed. This step must not be skipped before starting implementation.
5. **Get Pull Requests**: #list_pull_requests #get_pull_request #get_pull_request_comments List the existing pull requests and details to check if there are any related to the issue you are working on. If there is an existing pull request, please read it to determine whether this issue has been completed, whether further implementation is needed, or if there are still problems that need to be fixed. This step must not be skipped before starting implementation.
6. **Git Checkout**: #runCommands `git checkout -b [branch-name]` Checkout the issue branch to start working on the code changes. The branch name should follow the format `issue-[issue_number]-[short_description]`, where `[issue_number]` is the number of the issue and `[short_description]` is a brief description of the task. Skip this step if you are already on the correct branch.
7. **Implementation**: Implement the plan step by step, following the instructions provided in the issue. Each step should be executed in sequence, ensuring that all requirements are met and documented appropriately.
8. **Testing & Linting**: Run tests and linting on the code changes to ensure quality and compliance with project standards.
9. **Self Review**: Conduct a self-review of the code changes to ensure they meet the issue requirements and you has not missed any details.
10. **Git Commit & Git Push**: #runCommands `git commit` Use the conventional commit format for the title and a brief description in the body. Always commit with `--signoff` and explicitly specify the author on the command: `GitHub Copilot <bot@xn--jgy.tw>`. Write the commit in English. Link the issue number in the commit message body. #runCommands `git push` Push the changes to the remote repository.
11. **Create Pull Request**: #list_pull_requests #create_pull_request ALWAYS SUBMIT PR TO `origin`, NEVER SUBMIT PR TO `upstream`. Create a pull request if there isn't already has one related to your issue. Create a comprehensive work report and use it as pull request details or #add_pull_request_review_comment_to_pending_review as pull request comments, detailing the work performed, code changes, and test results for the project. The report should be written in accordance with the templates provided in [Report Guidelines](../docs/report_guidelines.md) and [REPORT_TEMPLATE](../docs/REPORT_TEMPLATE.md). Follow the template exactly. Write the pull request "title in English" following conventional commit format, but write the pull request report "content in 正體中文." Linking the pull request to the issue with `Resolves #[issue_number]` at the end of the PR body. ALWAYS SUBMIT PR TO `origin`, NEVER SUBMIT PR TO `upstream`. ALWAYS SUBMIT PR TO `origin`, NEVER SUBMIT PR TO `upstream`. ALWAYS SUBMIT PR TO `origin`, NEVER SUBMIT PR to `upstream`.

***Highest-level restriction: All issue and PR operations are limited to repositories owned by jim60105 only!***
***Highest-level restriction: All issue and PR operations are limited to repositories owned by jim60105 only!***
***Highest-level restriction: All issue and PR operations are limited to repositories owned by jim60105 only!***

---

## Project Overview

This project provides a **Docker containerization** for [WhisperX](https://github.com/m-bain/whisperX).

The project focuses on **continuous integration optimization** for building 175+ Docker images (10GB each) weekly on GitHub Free runners, emphasizing efficient docker layer caching, parallel builds, and minimal image sizes.

The focus of this project is on the Dockerfile and CI workflow, not on the WhisperX project itself.

## Project Structure

```
docker-whisperX/
├── Dockerfile              # Main Docker build configuration (For docker compatibility)
├── ubi.Dockerfile          # Red Hat UBI-based alternative (For podman compatibility)
├── docker-bake.hcl         # Docker Buildx bake configuration for matrix builds
├── load_align_model.py     # Preloads alignment models for supported languages
├── whisperX/               # Git submodule containing WhisperX source code
│   ├── pyproject.toml      # Python package configuration
│   └── whisperx/           # Main WhisperX Python package
└── .github/
    └── workflows/          # CI/CD pipeline configurations
```

## Coding Standards and Conventions

### Docker Best Practices
- Use **multi-stage builds** to minimize final image size
- Leverage **BuildKit features** like `--mount=type=cache` for dependency caching
- Apply **layer caching strategies** to optimize CI build times
- Use **ARG** variables for build-time configuration (WHISPER_MODEL, LANG, etc.)
- Follow **security best practices**: run as non-root user, minimize installed packages
- Do not use `--link` in ubi.Dockerfile, as it is not supported by Podman.
- Do not use `,z` or `,Z` in Dockerfile, as it is not supported by Docker buildx.

### Documentation Standards
- Write documentation in English for user-facing content
- Use **English** for technical comments in code and commit messages
- Include **clear examples** in README files showing actual usage commands
- Document **build arguments** and their acceptable values
- Provide **troubleshooting guidance** for common issues

## Key Technologies and Dependencies

### Build Tools
- **uv**: Modern Python package manager for dependency resolution (Used in Dockerfile)
- **Docker Buildx**: Extended build capabilities with bake support
- **GitHub Actions**: CI/CD automation for multi-architecture builds

## Development Guidelines

### When Working with Docker Configuration
- **Dockerfile modifications**: Always test both `amd64` and `arm64` architectures
- **Build arguments**: Validate that ARG values match supported languages in `load_align_model.py`
- **Cache optimization**: Consider layer ordering impact on CI build performance
- **Multi-stage builds**: Ensure each stage serves a clear purpose (build → no_model → load_whisper)

### When Working with CI/CD
- **Parallel builds**: Consider the large amount of build matrix impact on GitHub runner resources
- **Caching strategy**: Optimize for both build time and cache storage efficiency
- **Multi-architecture**: Ensure changes work correctly on both x86_64 and arm64

## Project-Specific Conventions

## Additional Notes for Contributors

When suggesting changes, always consider the impact on:
1. **Build time efficiency** for the CI pipeline
2. **Multi-architecture compatibility** (amd64/arm64)  

---

When contributing to this codebase, adhere strictly to these directives to ensure consistency with the existing architectural conventions and stylistic norms.
