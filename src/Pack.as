// c 2024-03-06
// m 2024-03-06

const string[] extensionsImage = { "dds", "gif", "jpeg", "jpg", "png", "webp" };

enum FileType {
    GameBox,
    Image,
    Map,
    Replay,
    Unknown,
    Zip
}

class Pack {
    string   checksum;
    string   file;
    string   lastuse;
    string   lastuseIso;
    uint     lastuseUnix = 0;
    string   name;
    string   path;
    string   root;
    uint     size;
    FileType type        = FileType::Unknown;

    Pack() { }
    Pack(XML::Node node) {
        checksum = node.Child("checksum").Content();
        file     = node.Child("file").Content();
        lastuse  = node.Child("lastuse").Content();
        name     = node.Child("name").Content();
        root     = node.Child("root").Content();
        size     = Text::ParseUInt(node.Child("size").Content());

        lastuseIso = lastuse.SubStr(6, 4) + "-" + lastuse.SubStr(3, 2) + "-" + lastuse.SubStr(0, 2) + " " + lastuse.SubStr(11, 2) + ":" + lastuse.SubStr(14, 2) + ":00";
        lastuseUnix = IsoToUnix(lastuseIso);

        if (file.StartsWith("Maps\\") || file.StartsWith("Skins\\"))
            path = IO::FromUserGameFolder(file).Replace("\\", "/");
        else if (file.StartsWith("Cache\\"))
            path = programDataPath + file.Replace("\\", "/");

        string[]@ parts = file.Split(".");

        if (parts.Length > 0) {
            string extension = parts[parts.Length - 1].ToLower();

            if (extension == "gbx") {
                type = FileType::GameBox;

                if (parts.Length > 1) {
                    string gbxType = parts[parts.Length - 2].ToLower();

                    if (gbxType == "map")
                        type = FileType::Map;
                    else if (gbxType == "replay")
                        type = FileType::Replay;
                }
            } else if (extensionsImage.Find(extension) > -1)
                type = FileType::Image;
            else if (extension == "zip")
                type = FileType::Zip;
        }
    }
}