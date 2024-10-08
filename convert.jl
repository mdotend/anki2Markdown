using SQLite
using DBInterface
using ZipFile
using JSON


# TODO: query collection
# TODO: transform notes into markdown format
# TODO  translate Math
# TODO: translate image path
# TODO: Order notes


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
        println(id)
    end
end

function html_to_markdown(input::String)
    replace(
        input,
        "<div>" => "\n",
        "</div>" => "",
        "<b>" => "**",
        "</b>" => "**",
        "\\(" => "\$",
        "\\)" => "\$"
    )
end

unzip_apkg("MI1.apkg", "tmp/")
rename_media("tmp/", "tmp/media", "output/media/")

db = SQLite.DB("tmp/collection.anki2")

# Example query
result = DBInterface.execute(db, "SELECT flds FROM notes")
for row in result
    println(html_to_markdown(row.flds))
end

SQLite.close(db)