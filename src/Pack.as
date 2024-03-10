// c 2024-03-06
// m 2024-03-10

const string[] extensionsArchive = { "7z", "gz", "rar", "tar", "zip" };
const string[] extensionsAudio   = { "aac", "aiff", "alac", "amr", "flac", "m4a", "m4r", "mp3", "mux", "ogg", "wav", "wma" };
const string[] extensionsImage   = { "bmp", "dds", "exr", "gif", "heif", "jpeg", "jpg", "tiff", "png", "svg", "tga", "webp" };
const string[] extensionsText    = { "as", "ini", "json", "log", "md", "toml", "txt", "xml" };
const string[] extensionsVideo   = { "avchd", "avi", "drc", "flv", "gifv", "m2ts", "mkv", "mov", "mp4", "mts", "ogv", "qt", "ts", "vob", "webm", "wmv" };

enum FileType {
    Archive,
    Audio,
    Block,
    CarSkin,
    FidCache,
    GameBox,
    Image,
    Item,
    Macroblock,
    Map,
    MapMod,
    Material,
    Mesh,
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
    uint     lastuseUnix     = 0;
    string   name;
    string   path;
    bool     permaCached     = false;
    bool     permaCacheIssue = false;
    string   root;
    uint     size            = 0;
    FileType type            = FileType::Unknown;
    string   url;

    Pack() { }
    Pack(XML::Node node) {
        checksum = node.Child("checksum").Content();
        file     = ForSlash(node.Child("file").Content());
        lastuse  = node.Child("lastuse").Content();
        name     = ForSlash(node.Child("name").Content());
        root     = node.Child("root").Content();
        size     = Text::ParseUInt(node.Child("size").Content());

        try {
            url = node.Child("url").Content();
        } catch { }

        lastuseIso = lastuse.SubStr(6, 4) + "-" + lastuse.SubStr(3, 2) + "-" + lastuse.SubStr(0, 2) + " " + lastuse.SubStr(11, 2) + ":" + lastuse.SubStr(14, 2) + ":00";
        lastuseUnix = IsoToUnix(lastuseIso);

        if (root == "shared")
            path = programDataPath + file;
        else if (root == "user")
            path = ForSlash(IO::FromUserGameFolder(file));
        else if (root == "data")
            path = ForSlash(IO::FromAppFolder("GameData")) + "/" + file;

        string[]@ parts = file.Split(".");

        if (parts.Length == 0)
            return;

        extension = parts[parts.Length - 1].ToLower();

        if (extensionsArchive.Find(extension) > -1) {
            type = FileType::Archive;

            parts = name.Split("/");

            if (parts.Length > 0 && parts[0] == "Skins") {
                if (parts.Length > 1) {
                    if (parts[1] == "Models" && parts.Length > 2 && parts[2] == "CarSport")
                        type = FileType::CarSkin;
                    else if (parts[1] == "Stadium" && parts.Length > 2 && parts[2] == "Mod")
                        type = FileType::MapMod;
                }
            }
        } else if (extensionsAudio.Find(extension) > -1)
            type = FileType::Audio;
        else if (extension == "gbx") {
            type = FileType::GameBox;

            if (parts.Length == 1)
                return;

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
            else if (gbxType == "mesh")
                type = FileType::Mesh;
            else if (gbxType == "profile")
                type = FileType::Profile;
            else if (gbxType == "replay")
                type = FileType::Replay;
            else if (gbxType == "scores")
                type = FileType::Scores;
            else if (gbxType == "systemconfig")
                type = FileType::SystemConfig;

        } else if (extensionsImage.Find(extension) > -1)
            type = FileType::Image;
        else if (extensionsText.Find(extension) > -1)
            type = FileType::Text;
        else if (extensionsVideo.Find(extension) > -1)
            type = FileType::Video;
    }

    void PermaCache() {
        if (type != FileType::CarSkin && type != FileType::MapMod)
            return;

        if (!IO::FileExists(path)) {
            warn("file not found: " + path);
            permaCacheIssue = true;
            return;
        }

        try {
            const string newPath = ForSlash(IO::FromUserGameFolder("")) + name;
            IO::Move(path, newPath);
            path = newPath;
            root = "user";
            permaCached = true;
        } catch {
            error("error moving file (" + path + "): " + getExceptionInfo());
            permaCacheIssue = true;
        }

        try {
            IO::File fileRead(checksumFile, IO::FileMode::Read);
            string xml = fileRead.ReadToEnd();
            fileRead.Close();

            const string nameBackSlash = name.Replace("/", "\\");

            xml = xml.Split("\n</cache>")[0];

            xml += "\n	<packdesc>";
            xml += "\n		<name>" + nameBackSlash + "</name>";
            xml += "\n		<root>user</root>";
            xml += "\n		<file>" + nameBackSlash + "</file>";
            xml += "\n		<checksum>" + checksum + "</checksum>";
            xml += "\n		<size>" + size + "</size>";
            xml += "\n		<lastuse>" + lastuse + "</lastuse>";
            xml += "\n	</packdesc>";
            xml += "\n</cache>";

            string toReplace = "\n	<packdesc>";
            toReplace += "\n		<name>" + nameBackSlash + "</name>";
            toReplace += "\n		<root>shared</root>";
            toReplace += "\n		<file>" + file.Replace("/", "\\") + "</file>";
            toReplace += "\n		<checksum>" + checksum + "</checksum>";
            toReplace += "\n		<size>" + size + "</size>";
            toReplace += "\n		<url>" + url + "</url>";
            toReplace += "\n		<lastuse>" + lastuse + "</lastuse>";
            toReplace += "\n	</packdesc>";

            if (xml.Contains(toReplace))
                xml = xml.Replace(toReplace, "");
            else {
                warn("toReplace not found in xml, old cache location remains and will probably cause a game crash");
                permaCacheIssue = true;
            }

            IO::File fileWrite(checksumFile, IO::FileMode::Write);
            fileWrite.Write(xml);
            fileWrite.Close();
        } catch {
            error("error writing checksum.txt: " + getExceptionInfo());
            permaCacheIssue = true;
        }
    }
}