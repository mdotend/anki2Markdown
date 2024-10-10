using SQLite
using DBInterface
using ZipFile
using JSON

# TODO: fix line breaks


function unzip_apkg(file_path::String, output_dir::String)
    r = ZipFile.Reader(file_path)
    for f in r.files
        #println("Filename: $(f.name)")
        write(joinpath(output_dir, f.name), read(f, String));
    end
    close(r)
end

function rename_media(tmp_path::String, name_file::String, output_path::String)
    for (id, name) in JSON.parsefile(name_file)
        mv(joinpath(tmp_path, id), joinpath(output_path, name))
    end
end

function build_image_path(name, layers, dir="_resources")
    path = joinpath(dir, name)
    foreach(_ -> path = joinpath("..", path), range(1,layers))
    return path
end

function transform_image!(input::String, layers::Integer)
    pattern = r"src=\"([^\"]+)\""
    m = collect(eachmatch(pattern, input))
    if length(m) > 0
        for img in m
            image_name = img.captures[1]
            resource = build_image_path(image_name, layers)
            input = replace(input, r"<img.*?>" => "![$image_name]($resource)\n", count=1)
        end
    end
    return input
end

function html_to_markdown(input::String, title::String, layers::Integer)
    input = transform_image!(input, layers)
    # translate html elements to markdown
    input = replace(
        input,
        "\x1f" => "\n",
        "<div>" => "\n",
        "</div>" => "\n",
        "<b>" => "**",
        "</b>" => "**",
        "<u>" => "### ",
        "</u>" => "",
        "<i>" => "*",
        "</i>" => "*",
        "<br>" => "\n",
        "&nbsp;" => "\t",
        "\\(" => "\$",
        "\\)" => "\$",
        "&gt;" => ">",
        "&lt;" => "<",
    )
    
    if occursin(r".+:", title) 
        input = replace(input, r".+:" => "##", count=1)
    else
        input = replace(input, title => "## " * title)
    end
    # cleanup artifacte
    input = replace(input,
        r"\*\*\s+\*\*" => "",
        r"\n+" => "\n",
    )
    return input
end

function group_notes!(topics::Dict, note::String, tags::String)
    if tags != ""
        topic = rstrip(split(tags, ",")[1])
    else
        topic = "default"
    end

    note = note * "\n\n"
    
    if haskey(topics, topic)
        push!(topics[topic], note)
    else
        topics[topic] = [note]
    end
end

# mkpath("tmp")
# mkpath("output/media")

# unzip_apkg("MI1.apkg", "tmp/")
# rename_media("tmp/", "tmp/media", "output/media/")

db = SQLite.DB("tmp/collection.anki2")
result = DBInterface.execute(db, "SELECT id, sfld, flds, tags FROM notes")
notes = Dict{String, Vector{String}}()

for row in result
    note = html_to_markdown(row.flds, row.sfld, 4)
    group_notes!(notes, note, row.tags)
    # if contains(row.flds, "decision boundary")
    #     println(row)
    # end
end

for topic in notes
    open(joinpath("output/", topic[1] * ".md"), "w+") do file
        for note in topic[2]
            write(file, note)
        end
    end
end

SQLite.close(db)

#rm("tmp/", recursive=true)