//
//  ContentView.swift
//  Demo
//
//  Created by kintan on 2020/3/22.
//  Copyright © 2020 kintan. All rights reserved.
//

import KSPlayer
import SwiftUI

struct ContentView: View {
    @State var showAddActionSheet = false
    @State private var resources = [KSPlayerResource]()
    @State private var playURL: String = ""
    @State private var playList: String = ""

    var body: some View {
        NavigationView {
            MasterView(resources: $resources)
                .navigationTitle("m3u8")
            #if !os(macOS)
                .navigationBarItems(trailing: Button(action: {
                    showAddActionSheet = true
                }) {
                    Image(systemName: "plus")
                })
            #endif
        }.onAppear {
            self.loadCachem3u8()
            if self.resources.count == 0 {
                self.updatem3u8("https://iptv-org.github.io/iptv/countries/cn.m3u")
            }
        }.sheet(isPresented: $showAddActionSheet) {} content: {
            Text("Input URL")
            TextField("play url", text: $playURL)
            TextField("play list", text: $playList)
            Button("Done") {
                if let url = URL(string: playURL.trimmingCharacters(in: NSMutableCharacterSet.whitespacesAndNewlines)) {
                    self.resources.insert(KSPlayerResource(url: url, options: KSOptions(), name: "new add"), at: 0)
                } else if !playList.isEmpty {
                    self.updatem3u8(playList.trimmingCharacters(in: NSMutableCharacterSet.whitespacesAndNewlines))
                }
                showAddActionSheet = false
            }
        }
    }

    private func loadCachem3u8() {
        guard var path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        path.appendPathComponent("cache.m3u8")
        if FileManager.default.fileExists(atPath: path.path) {
            do {
                let data = try Data(contentsOf: path)
                guard let string = String(data: data, encoding: .utf8) else {
                    return
                }
                resources.removeAll()
                resources.append(contentsOf: parsem3u8(string: string))
            } catch {}
        }
    }

    private func updatem3u8(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let string = String(data: data, encoding: .utf8) else {
                return
            }
            self.saveToDocument(data: data, filename: "cache.m3u8")
            self.resources.removeAll()
            self.resources.append(contentsOf: self.parsem3u8(string: string))
        }.resume()
    }

    private func parsem3u8(string: String) -> [KSPlayerResource] {
        string.components(separatedBy: "#EXTINF:").compactMap { content in
            let array = content.split(separator: "\n")
            guard array.count > 1, let url = URL(string: String(array[1])) else {
                return nil
            }
            guard let name = array[0].split(separator: ",").last else {
                return nil
            }
            return KSPlayerResource(url: url, options: KSOptions(), name: String(name))
        }
    }

    private func saveToDocument(data: Data, filename: String) {
        guard var path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        path.appendPathComponent(filename)
        if FileManager.default.fileExists(atPath: path.absoluteString) {
            do {
                try FileManager.default.removeItem(at: path)
            } catch {}
        }
        do {
            try data.write(to: path)
        } catch {}
    }
}

struct MasterView: View {
    @Binding var resources: [KSPlayerResource]
    @State private var searchText = ""
    var body: some View {
        VStack {
            TextField("Search", text: $searchText)
            List {
                ForEach(resources.filter { $0.name.contains(searchText) || searchText.count == 0 }, id: \.self) { resource in
                    NavigationLink(resource.name, destination: KSVideoPlayerView(resource: resource))
                }.onDelete { indices in
                    indices.forEach { self.resources.remove(at: $0) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension KSVideoPlayerView {
    init(resource: KSPlayerResource) {
        let definition = resource.definitions.first!
        self.init(url: definition.url, options: definition.options)
    }
}
