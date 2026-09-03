//
//  MindMapView.swift
//  Docked
//
//  A pocket mind map. Add nodes, drag them around, rename the selected one and
//  link nodes together. Persists to UserDefaults.
//

import SwiftUI
import Foundation

private struct MMNode: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var x: Double    // 0…1
    var y: Double
}

private struct MMDoc: Codable {
    var nodes: [MMNode] = []
    var links: [[String]] = []   // pairs of node id strings
}

struct MindMapView: View {
    @AppStorage("docked.mindmap") private var raw: Data = Data()

    @State private var nodes: [MMNode] = []
    @State private var links: [[String]] = []
    @State private var selected: UUID? = nil
    @State private var linking = false

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    Canvas { ctx, _ in
                        for pair in links {
                            guard pair.count == 2,
                                  let a = node(pair[0]), let b = node(pair[1]) else { continue }
                            var p = Path()
                            p.move(to: CGPoint(x: a.x * w, y: a.y * h))
                            p.addLine(to: CGPoint(x: b.x * w, y: b.y * h))
                            ctx.stroke(p, with: .color(Theme.accent.opacity(0.5)), lineWidth: 2)
                        }
                    }

                    ForEach(nodes) { n in
                        nodeView(n, w: w, h: h)
                    }
                }
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .onTapGesture { selected = nil }
            }

            controls
        }
        .onAppear(perform: loadDoc)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { addNode() } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)

            if let id = selected, let idx = nodes.firstIndex(where: { $0.id == id }) {
                TextField("Idea", text: Binding(
                    get: { nodes[idx].text },
                    set: { nodes[idx].text = $0; saveDoc() }))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                Button { linking.toggle() } label: {
                    Image(systemName: linking ? "link.circle.fill" : "link.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(linking ? Theme.accent : Color.secondary)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) { deleteSelected() } label: {
                    Image(systemName: "trash").font(.system(size: 18)).foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                Text(nodes.isEmpty ? "Tap ＋ to add a node" : "Tap a node to edit")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
    }

    private func nodeView(_ n: MMNode, w: CGFloat, h: CGFloat) -> some View {
        let isSel = selected == n.id
        return Text(n.text.isEmpty ? "…" : n.text)
            .font(.system(size: 12, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSel ? Theme.accent : Theme.paper,
                       in: Capsule())
            .overlay(Capsule().stroke(Theme.accent, lineWidth: isSel ? 0 : 1.5))
            .foregroundStyle(isSel ? Color(red: 0.11, green: 0.08, blue: 0.02) : Color.primary)
            .position(x: CGFloat(n.x) * w, y: CGFloat(n.y) * h)
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        guard let idx = nodes.firstIndex(where: { $0.id == n.id }) else { return }
                        nodes[idx].x = min(max(Double(v.location.x / max(w, 1)), 0.05), 0.95)
                        nodes[idx].y = min(max(Double(v.location.y / max(h, 1)), 0.05), 0.95)
                    }
                    .onEnded { _ in saveDoc() }
            )
            .onTapGesture { tapNode(n.id) }
    }

    // MARK: model

    private func node(_ idString: String) -> MMNode? {
        nodes.first { $0.id.uuidString == idString }
    }

    private func tapNode(_ id: UUID) {
        if linking, let from = selected, from != id {
            toggleLink(from, id)
            linking = false
        } else {
            selected = id
        }
    }

    private func toggleLink(_ a: UUID, _ b: UUID) {
        let key = [a.uuidString, b.uuidString].sorted()
        if let i = links.firstIndex(where: { $0.sorted() == key }) {
            links.remove(at: i)
        } else {
            links.append(key)
        }
        saveDoc()
    }

    private func addNode() {
        let n = MMNode(text: "Idea \(nodes.count + 1)",
                       x: Double.random(in: 0.3...0.7),
                       y: Double.random(in: 0.3...0.7))
        nodes.append(n)
        selected = n.id
        saveDoc()
    }

    private func deleteSelected() {
        guard let id = selected else { return }
        nodes.removeAll { $0.id == id }
        links.removeAll { $0.contains(id.uuidString) }
        selected = nil
        saveDoc()
    }

    private func loadDoc() {
        guard !raw.isEmpty, let doc = try? JSONDecoder().decode(MMDoc.self, from: raw) else { return }
        nodes = doc.nodes
        links = doc.links
    }

    private func saveDoc() {
        if let data = try? JSONEncoder().encode(MMDoc(nodes: nodes, links: links)) {
            raw = data
        }
    }
}
