// c 2024-03-06
// m 2024-03-06

const string[] extensionsArchive = { "7z", "gz", "rar", "tar", "zip" };
const string[] extensionsAudio   = { "aac", "aiff", "alac", "flac", "m4a", "mp3", "mux", "ogg", "wav", "wma" };
const string[] extensionsImage   = { "bmp", "dds", "exr", "gif", "heif", "jpeg", "jpg", "tiff", "png", "svg", "tga", "webp" };
const string[] extensionsText    = { "as", "ini", "json", "log", "md", "toml", "txt", "xml" };
const string[] extensionsVideo   = { "avchd", "avi", "drc", "flv", "gifv", "m2ts", "mkv", "mov", "mp4", "mts", "ogv", "qt", "ts", "vob", "webm", "wmv" };

enum FileType {
    Archive,
    Audio,
    Block,
    FidCache,
    GameBox,
    Image,
    Item,
    Macroblock,
    Map,
    Material,
    Profile,
    Replay,
    Scores,
    SystemConfig,
    Text,
    Unknown,
    Video
}

class Pack {
    string   checksum;
    string   extension;
    string   file;
    string   lastuse;
    string   lastuseIso;
    uint     lastuseUnix = 0;
    string   name;
    string   path;
    string   root;
    uint     size        = 0;
    FileType type        = FileType::Unknown;

    Pack() { }
    Pack(XML::Node node) {
        checksum = node.Child("checksum").Content();
        file     = node.Child("file").Content();
        lastuse  = node.Child("lastuse").Content();
        name     = node.Child("name").Content().Replace("\\", "/");
        root     = node.Child("root").Content();
        size     = Text::ParseUInt(node.Child("size").Content());

        lastuseIso = lastuse.SubStr(6, 4) + "-" + lastuse.SubStr(3, 2) + "-" + lastuse.SubStr(0, 2) + " " + lastuse.SubStr(11, 2) + ":" + lastuse.SubStr(14, 2) + ":00";
        lastuseUnix = IsoToUnix(lastuseIso);

        if (file.StartsWith("Maps\\") || file.StartsWith("Skins\\") || file.StartsWith("Media\\"))
            path = IO::FromUserGameFolder(file).Replace("\\", "/");
        else if (file.StartsWith("Cache\\"))
            path = programDataPath + file.Replace("\\", "/");

        string[]@ parts = file.Split(".");

        if (parts.Length > 0) {
            extension = parts[parts.Length - 1].ToLower();

            if (extensionsArchive.Find(extension) > -1)
                type = FileType::Archive;
            else if (extensionsAudio.Find(extension) > -1)
                type = FileType::Audio;
            else if (extension == "gbx") {
                type = FileType::GameBox;

                if (parts.Length > 1) {
                    string gbxType = parts[parts.Length - 2].ToLower();

                    if (gbxType == "block")
                        type = FileType::Block;
                    else if (gbxType == "fidcache")
                        type = FileType::FidCache;
                    else if (gbxType == "item")
                        type = FileType::Item;
                    else if (gbxType == "macroblock")
                        type = FileType::Macroblock;
                    else if (gbxType == "map")
                        type = FileType::Map;
                    else if (gbxType == "mat")
                        type = FileType::Material;
                    else if (gbxType == "profile")
                        type = FileType::Profile;
                    else if (gbxType == "replay")
                        type = FileType::Replay;
                    else if (gbxType == "scores")
                        type = FileType::Scores;
                    else if (gbxType == "systemconfig")
                        type = FileType::SystemConfig;
                }
            } else if (extensionsImage.Find(extension) > -1)
                type = FileType::Image;
            else if (extensionsText.Find(extension) > -1)
                type = FileType::Text;
            else if (extensionsVideo.Find(extension) > -1)
                type = FileType::Video;
        }
    }
}