module GitHubArtifactServer

import JSON
import Downloads
import HTTP
import LiveServer
import p7zip_jll
import REPL.TerminalMenus

export serve_artifact

token() = Base.get(ENV, "GITHUB_TOKEN") do
    readchomp(`gh auth token`)
end

geturl(url) = JSON.parse(IOBuffer(HTTP.get(url, Dict("Authorization" => "token $(token())")).body))
get(parts...) = geturl(url(parts...))

url(parts...) = join(["https://api.github.com", parts...], "/")

artifacts_url(repo, run_id) = get("repos", repo, "actions", "runs", run_id)["artifacts_url"]
artifacts(repo, run_id) = geturl(artifacts_url(repo, run_id))["artifacts"]

function simple_progress(total::Int, bytes::Int)
    percent = total > 0 ? bytes / total * 100 : 0
    print("\rDownloading: $(round(percent, digits=2))%")
end

function _serve(artifact; prefix)
    mktempdir() do dir
        zipfile = joinpath(dir, "artifact.zip")
        println()
        Downloads.download(
            artifact["archive_download_url"],
            zipfile;
            headers = Dict("Authorization" => "token $(token())"),
            progress = simple_progress
        )
        println()

        artifactdir = joinpath(dir, "artifact")
        unzipdir = joinpath(artifactdir, prefix)
        mkpath(unzipdir)

        # Run the 7z command to extract the contents of the zip file
        run(`$(p7zip_jll.p7zip()) x -bd $zipfile -o$unzipdir`)

        LiveServer.serve(; dir = artifactdir, launch_browser = true)
    end
end

"""
    serve_artifact(url; prefix = "")

Takes a `url` of one of these forms:

- `"https://github.com/SomeUser/SomeRepo.jl/actions/runs/12345678/..."` (the trailing content does not matter, important is the `runs/12345678` part)
- `"https://github.com/SomeUser/SomeRepo.jl/pull/1234"` (takes last commit)

It then queries workflow artifacts for the associated run or runs and downloads the one you pick. It then unzips the contents to a temporary
directory and serves it via `LiveServer.jl`. It is intended for looking at artifacts such as doc builds.

You can set `ENV["GITHUB_TOKEN"]` for authorization. Otherwise, `gh auth token` is tried as a fallback.

The `prefix` can be used if what you view only works with some prefix, like a baked in
`previews/PR4567`.
"""
function serve_artifact(url; prefix = "")
    run_match = Base.match(r"github\.com/([^/]+/[^/]+)/actions/runs/(\d+)/?", url)
    pr_match = Base.match(r"github\.com/([^/]+/[^/]+)/pull/(\d+)/?", url)

    function handle_artifacts(_artifacts)
        if isempty(_artifacts)
            println("No artifacts available")
        elseif length(_artifacts) == 1
            _serve(only(_artifacts); prefix)
        else
            _artifact = pick(_artifacts) do artifact
                artifact["name"]
            end
            _serve(_artifact; prefix)
        end
    end

    if run_match !== nothing
        repo = run_match.captures[1]
        run_id = run_match.captures[2]
        _artifacts = artifacts(repo, run_id)
    elseif pr_match !== nothing
        repo = pr_match.captures[1]
        pr_id = pr_match.captures[2]
        _artifacts = get_artifacts_for_pr(repo, pr_id)
    else
        println("Could not extract repo and run id from url \"$url\"")
        return
    end

    handle_artifacts(_artifacts)
end

function get_artifacts_for_pr(repo, pr_id)
    pr = get("repos", repo, "pulls", pr_id)
    head_sha = pr["head"]["sha"]
    println("Head SHA is $head_sha")
    check_runs = get("repos", repo, "commits", head_sha, "check-runs")["check_runs"]
    run_ids = unique(map(check_runs) do check_run
        match(r"runs/(\d+)", check_run["html_url"]).captures[1]
    end)
    mapreduce(vcat, run_ids) do run_id
        artifacts(repo, run_id)
    end
end



function pick(f_name, vector)
    menu = TerminalMenus.RadioMenu(String[f_name(v) for v in vector])
    println("Which artifact do you want to serve?")
    selection = TerminalMenus.request(menu)
    return vector[selection]
end

end

