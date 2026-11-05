pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// To-dos and a scratch note, saved to ~/.local/share/qs-notes.json so they survive restarts.
Singleton {
    id: root

    readonly property alias todos: todoModel
    property string note: ""
    readonly property string path: Quickshell.env("HOME") + "/.local/share/qs-notes.json"
    property bool loaded: false

    ListModel { id: todoModel }

    function add(text) {
        text = text.trim()
        if (text === "") return
        todoModel.insert(0, { text: text, done: false })
        save()
    }
    function toggle(i) { todoModel.setProperty(i, "done", !todoModel.get(i).done); save() }
    function remove(i) { todoModel.remove(i); save() }
    function setNote(t) { root.note = t; saveSoon.restart() }

    function save() {
        var items = []
        for (var i = 0; i < todoModel.count; i++) items.push({ text: todoModel.get(i).text, done: todoModel.get(i).done })
        file.setText(JSON.stringify({ todos: items, note: root.note }))
    }

    Timer { id: saveSoon; interval: 600; onTriggered: root.save() }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        onLoaded: {
            try {
                var d = JSON.parse(text())
                todoModel.clear()
                for (var i = 0; i < (d.todos || []).length; i++) todoModel.append({ text: d.todos[i].text, done: !!d.todos[i].done })
                root.note = d.note || ""
            } catch (e) {}
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
}
