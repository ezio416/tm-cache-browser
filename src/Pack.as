// c 2024-03-06
// m 2024-03-06

class Pack {
    string checksum;
    string file;
    string lastuse;
    string name;
    string root;
    uint   size;

    Pack() { }
    Pack(XML::Node node) {
        checksum = node.Child("checksum").Content();
        file     = node.Child("file").Content();
        lastuse  = node.Child("lastuse").Content();
        name     = node.Child("name").Content();
        root     = node.Child("root").Content();
        size     = Text::ParseUInt(node.Child("size").Content());
    }
}