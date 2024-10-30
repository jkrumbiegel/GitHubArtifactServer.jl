# GitHubArtifactServer

[![Build Status](https://github.com/jkrumbiegel/GitHubArtifactServer.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jkrumbiegel/GitHubArtifactServer.jl/actions/workflows/CI.yml?query=branch%3Amain)

`GitHubArtifactServer.jl` is a Julia package to quickly view the content of artifacts from GitHub Actions workflows in a browser. This is especially useful for artifacts like generated documentation without downloading or manually unzipping files. The package retrieves, downloads, and serves selected artifacts from GitHub repositories in a local server environment using `LiveServer.jl`.

## Usage

Just go to the page of a GitHub workflow that contains the workflow you're interested in. The exact URL is not important but it needs to contain the repo and the `actions/runs/12345678` part.

```julia
using GitHubArtifactServer

serve_artifact("https://github.com/SomeUser/SomeRepo.jl/actions/runs/12345678")
serve_artifact("https://github.com/SomeUser/SomeRepo.jl/pull/1234") # last commit of that PR
```

If there are multiple artifacts, you will be asked which one you want.
The temporary directory is deleted when the server is interrupted with ctrl+c.

### Authorization

For authorization, you need to provide a GitHub token. You can do this in one of two ways:

1. Set the environment variable `GITHUB_TOKEN`:

   ```bash
   export GITHUB_TOKEN="your_token_here"
   ```

2. Ensure that the `gh` CLI is authenticated. The package will use `gh auth token` to obtain the token if `GITHUB_TOKEN` is not set.
