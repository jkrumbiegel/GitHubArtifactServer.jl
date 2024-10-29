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

function _serve(artifact)
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

        unzipdir = joinpath(dir, "artifact")
        mkdir(unzipdir)

        # Run the 7z command to extract the contents of the zip file
        run(`$(p7zip_jll.p7zip()) x -bd $zipfile -o$unzipdir`)

        LiveServer.serve(; dir = unzipdir, launch_browser = true)
    end
end

"""
    serve_artifact(url)

Takes a `url` of the form `"https://github.com/SomeUser/SomeRepo.jl/actions/runs/12345678/..."`
(the trailing content does not matter, important is the `runs/12345678` part), queries workflow
artifacts for that run and downloads the one you pick. It then unzips the contents to a temporary
directory and serves it via `LiveServer.jl`. It is intended for looking at artifacts such as doc builds.

You can set `ENV["GITHUB_TOKEN"]` for authorization. Otherwise, `gh auth token` is tried as a fallback.
"""
function serve_artifact(url)
    pattern = r"github\.com/([^/]+/[^/]+)/actions/runs/(\d+)/?"

    match = Base.match(pattern, url)
    if match !== nothing
        repo = match.captures[1]
        run_id = match.captures[2]
        
        _artifacts = artifacts(repo, run_id)
        if isempty(_artifacts)

        elseif length(_artifacts) == 1
            _serve(only(_artifacts))
        else
            _artifact = pick(_artifacts) do artifact
                artifact["name"]
            end
            _serve(_artifact)
        end
    else
        println("Could not extract repo and run id from url \"$url\"")
    end
end

function pick(f_name, vector)
    menu = TerminalMenus.RadioMenu(String[f_name(v) for v in vector])
    println("Which artifact do you want to serve?")
    selection = TerminalMenus.request(menu)
    return vector[selection]
end

end

