// c 2024-03-10
// m 2024-03-10

void RenderDebug() {
    if (!S_Debug) {
        return;
    }

    UI::Begin(title + " (Debug)", S_Debug, UI::WindowFlags::None);
        UI::Text("Columns are sorted based on main window");
        UI::Text("Click any value to copy to clipboard");

        if (UI::BeginTable("table-debug", 15, UI::TableFlags::Resizable | UI::TableFlags::RowBg | UI::TableFlags::ScrollY)) {
            UI::PushStyleColor(UI::Col::TableRowBgAlt, rowBgAltColor);

            UI::TableSetupScrollFreeze(0, 1);
            UI::TableSetupColumn("type",        UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 65.0f);
            UI::TableSetupColumn("size",        UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 65.0f);
            UI::TableSetupColumn("root",        UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 65.0f);
            UI::TableSetupColumn("ext",         UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 65.0f);
            UI::TableSetupColumn("pCached",     UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 65.0f);
            UI::TableSetupColumn("pCIssue",     UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 65.0f);
            UI::TableSetupColumn("lastuse",     UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 120.0f);
            UI::TableSetupColumn("lastuseIso",  UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 130.0f);
            UI::TableSetupColumn("lastuseUnix", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoResize, scale * 80.0f);
            UI::TableSetupColumn("nameOld");
            UI::TableSetupColumn("name");
            UI::TableSetupColumn("file");
            UI::TableSetupColumn("path");
            UI::TableSetupColumn("checksum");
            UI::TableSetupColumn("url");
            UI::TableHeadersRow();

            UI::ListClipper clipper(packsSorted.Length);
            while (clipper.Step()) {
                for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                    Pack@ pack = packsSorted[i];

                    UI::TableNextRow();

                    UI::TableNextColumn();
                    if (UI::Selectable(tostring(pack.type), false)) {
                        IO::SetClipboard(tostring(pack.type));
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(tostring(pack.size), false)) {
                        IO::SetClipboard(tostring(pack.size));
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.root, false)) {
                        IO::SetClipboard(pack.root);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.extension, false)) {
                        IO::SetClipboard(pack.extension);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(tostring(pack.permaCached), false)) {
                        IO::SetClipboard(tostring(pack.permaCached));
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(tostring(pack.permaCacheIssue), false)) {
                        IO::SetClipboard(tostring(pack.permaCacheIssue));
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.lastuse, false)) {
                        IO::SetClipboard(pack.lastuse);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.lastuseIso, false)) {
                        IO::SetClipboard(pack.lastuseIso);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(tostring(pack.lastuseUnix), false)) {
                        IO::SetClipboard(tostring(pack.lastuseUnix));
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.nameOld, false)) {
                        IO::SetClipboard(pack.nameOld);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.name, false)) {
                        IO::SetClipboard(pack.name);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.file, false)) {
                        IO::SetClipboard(pack.file);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.path, false)) {
                        IO::SetClipboard(pack.path);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.checksum, false)) {
                        IO::SetClipboard(pack.checksum);
                    }

                    UI::TableNextColumn();
                    if (UI::Selectable(pack.url, false)) {
                        IO::SetClipboard(pack.url);
                    }
                }
            }

            UI::PopStyleColor();
            UI::EndTable();
        }

    UI::End();
}
