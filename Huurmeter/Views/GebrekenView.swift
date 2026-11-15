import SwiftUI
import SwiftData
import PhotosUI
import WWSKit
import HuurmeterCore

/// Functie 9: gebreken bijhouden, met foto's, melddatum en de termijnen voor de Huurcommissie.
struct GebrekenView: View {
    @Environment(\.modelContext) private var context
    @Bindable var woning: Woning
    private let regels = try? GebrekenRegels.laad()
    private let procedure = (try? Stappenplannen.laad())?.procedure("gebreken")
    @State private var nieuwGebrek: Gebrek?

    private var open: [Gebrek] { woning.gebreken.filter(\.open).sorted { $0.ontdekt > $1.ontdekt } }
    private var verholpen: [Gebrek] { woning.gebreken.filter { !$0.open }.sorted { $0.ontdekt > $1.ontdekt } }

    var body: some View {
        List {
            if woning.gebreken.isEmpty {
                Section {
                    Text("Houd hier gebreken bij zoals lekkage, schimmel of een kapotte verwarming. Leg ze vast met foto's en noteer wanneer u ze meldde.")
                        .foregroundStyle(.secondary)
                }
            }
            if !open.isEmpty {
                Section("Open") { ForEach(open) { rij($0) }.onDelete { verwijder($0, uit: open) } }
            }
            if !verholpen.isEmpty {
                Section("Verholpen") { ForEach(verholpen) { rij($0) }.onDelete { verwijder($0, uit: verholpen) } }
            }
            if let regels, let huur = woning.kaleHuur {
                let cats = Set(open.compactMap(\.categorie))
                if let l = regels.laagsteHuur(huur: huur, categorieen: cats) {
                    Section {
                        LabeledContent("Huur kan omlaag tot", value: Opmaak.euro(l.huur))
                    } header: {
                        Text("Huurverlaging")
                    } footer: {
                        Text("Dit is de ondergrens: de Huurcommissie kan de huur bij deze gebreken verlagen tot \(Int((l.percentage * 100).rounded()))% van uw huur. Hoeveel het precies wordt, bepaalt zij met haar gebrekenboek. \(regels.geenHuurverhoging.tekst.vertaald) Bron: \(l.bron); \(regels.geenHuurverhoging.bron).")
                    }
                }
            }
            Section {
                NavigationLink {
                    StappenplanView(woning: woning)
                } label: {
                    Label("Stappenplan Huurcommissie", systemImage: "list.number")
                }
                if !woning.gebreken.isEmpty {
                    ShareLink(item: Self.overzicht(woning)) {
                        Label("Gebrekenlijst delen", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle("Gebreken")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let g = Gebrek()
                    context.insert(g)
                    g.woning = woning
                    nieuwGebrek = g
                } label: {
                    Label("Gebrek toevoegen", systemImage: "plus")
                }
            }
        }
        .navigationDestination(item: $nieuwGebrek) { g in
            GebrekBewerken(gebrek: g, regels: regels, procedure: procedure)
        }
    }

    private func rij(_ g: Gebrek) -> some View {
        NavigationLink {
            GebrekBewerken(gebrek: g, regels: regels, procedure: procedure)
        } label: {
            HStack(spacing: 12) {
                if let data = g.fotos.first, let beeld = UIImage(data: data) {
                    Image(uiImage: beeld).resizable().scaledToFill()
                        .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.titel.isEmpty ? String(localized: "Naamloos gebrek") : g.titel).font(.headline)
                    Text(status(g)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func status(_ g: Gebrek) -> String {
        if let v = g.verholpen { return String(localized: "Verholpen op \(Dag(v).description)") }
        guard let m = g.gemeld else { return String(localized: "Nog niet gemeld bij de verhuurder") }
        let gemeld = Dag(m).description
        guard let procedure else { return String(localized: "Gemeld op \(gemeld)") }
        let t = procedure.termijnen(anker: Dag(m), vandaag: Dag(Date()))
        if t.verlopen { return String(localized: "Gemeld op \(gemeld) · termijn Huurcommissie verstreken") }
        if let v = t.vroegst, v > Dag(Date()) { return String(localized: "Gemeld op \(gemeld) · Huurcommissie vanaf \(v.description)") }
        return String(localized: "Gemeld op \(gemeld) · Huurcommissie tot \(t.uiterlijk.description)")
    }

    private func verwijder(_ offsets: IndexSet, uit lijst: [Gebrek]) {
        for i in offsets { context.delete(lijst[i]) }
    }

    static func overzicht(_ w: Woning) -> String {
        var regels = ["Gebreken \(w.titel)", ""]
        for g in w.gebreken.sorted(by: { $0.ontdekt < $1.ontdekt }) {
            regels.append("• \(g.titel.isEmpty ? "Gebrek" : g.titel)" + (g.ruimte.isEmpty ? "" : " (\(g.ruimte))"))
            if !g.omschrijving.isEmpty { regels.append("  \(g.omschrijving)") }
            regels.append("  Ontdekt: \(Dag(g.ontdekt))" + (g.gemeld.map { " · gemeld: \(Dag($0))" } ?? " · nog niet gemeld")
                          + (g.verholpen.map { " · verholpen: \(Dag($0))" } ?? ""))
            if let c = g.categorie { regels.append("  Categorie \(c.rawValue) (Bijlage II Besluit huurprijzen woonruimte)") }
        }
        return regels.joined(separator: "\n")
    }
}

private struct GebrekBewerken: View {
    @Environment(\.modelContext) private var context
    @Bindable var gebrek: Gebrek
    let regels: GebrekenRegels?
    let procedure: Stappenplannen.Procedure?
    @State private var keuze: [PhotosPickerItem] = []

    private func datum(_ pad: ReferenceWritableKeyPath<Gebrek, Date?>) -> Binding<Bool> {
        Binding(get: { gebrek[keyPath: pad] != nil }, set: { gebrek[keyPath: pad] = $0 ? Date() : nil })
    }

    private func dag(_ pad: ReferenceWritableKeyPath<Gebrek, Date?>) -> Binding<Date> {
        Binding(get: { gebrek[keyPath: pad] ?? Date() }, set: { gebrek[keyPath: pad] = $0 })
    }

    var body: some View {
        Form {
            Section {
                TextField("Wat is er mis? Bijv. lekkage badkamer", text: $gebrek.titel)
                TextField("Ruimte", text: $gebrek.ruimte)
                TextField("Omschrijving", text: $gebrek.omschrijving, axis: .vertical).lineLimit(3...8)
                DatePicker("Ontdekt op", selection: $gebrek.ontdekt, in: ...Date(), displayedComponents: .date)
            }

            Section {
                if !gebrek.fotos.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Array(gebrek.fotos.enumerated()), id: \.offset) { i, data in
                                if let beeld = UIImage(data: data) {
                                    Image(uiImage: beeld).resizable().scaledToFill()
                                        .frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 8))
                                        .contextMenu {
                                            Button("Verwijder foto", role: .destructive) { gebrek.fotos.remove(at: i) }
                                        }
                                        .accessibilityLabel("Foto \(i + 1)")
                                }
                            }
                        }
                    }
                }
                PhotosPicker(selection: $keuze, maxSelectionCount: 6, matching: .images) {
                    Label("Foto's toevoegen", systemImage: "camera")
                }
            } header: {
                Text("Foto's")
            } footer: {
                Text("Foto's blijven op uw telefoon. Houd een foto ingedrukt om hem te verwijderen.")
            }

            Section {
                Toggle("Gemeld bij de verhuurder", isOn: datum(\.gemeld))
                if gebrek.gemeld != nil {
                    DatePicker("Gemeld op", selection: dag(\.gemeld), in: ...Date(), displayedComponents: .date)
                    if let procedure, let m = gebrek.gemeld {
                        let t = procedure.termijnen(anker: Dag(m), vandaag: Dag(Date()))
                        if let v = t.vroegst { LabeledContent("Huurcommissie vanaf", value: v.description) }
                        LabeledContent("Huurcommissie uiterlijk", value: t.uiterlijk.description)
                    }
                }
                Toggle("Verholpen", isOn: datum(\.verholpen))
                if gebrek.verholpen != nil {
                    DatePicker("Verholpen op", selection: dag(\.verholpen), in: ...Date(), displayedComponents: .date)
                }
            } header: {
                Text("Melding")
            } footer: {
                Text(procedure.map { "Meld het gebrek schriftelijk. Is het zes weken later niet verholpen, dan kunt u naar de Huurcommissie, tot zes maanden na de melding (\($0.uiterste.bron))." } ?? "Meld het gebrek schriftelijk bij de verhuurder.")
            }

            if let regels {
                Section {
                    Picker("Categorie", selection: $gebrek.categorieRaw) {
                        Text("Weet ik niet").tag(String?.none)
                        ForEach(regels.categorieen) { c in
                            Text(verbatim: "\(c.code.rawValue): \(c.titel.vertaald)").tag(String?.some(c.code.rawValue))
                        }
                    }
                    if let c = gebrek.categorie.flatMap({ regels.categorie($0) }) {
                        ForEach(c.voorbeelden, id: \.self) { Text(verbatim: "• \($0.vertaald)").font(.footnote) }
                    }
                } header: {
                    Text("Ernst volgens de Huurcommissie")
                } footer: {
                    Text("Categorieën uit Bijlage II bij het Besluit huurprijzen woonruimte. Twijfelt u, kies dan 'Weet ik niet'; de Huurcommissie beoordeelt het zelf.")
                }
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle(gebrek.titel.isEmpty ? String(localized: "Nieuw gebrek") : gebrek.titel)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Leeg achtergelaten: opruimen.
            if gebrek.titel.isEmpty && gebrek.omschrijving.isEmpty && gebrek.fotos.isEmpty
                && gebrek.gemeld == nil && gebrek.categorie == nil { context.delete(gebrek) }
            else { gebrek.woning?.geraakt() }
        }
        .onChange(of: keuze) {
            let items = keuze
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let beeld = UIImage(data: data),
                       let jpeg = beeld.verkleind(maximaleZijde: 1600).jpegData(compressionQuality: 0.7) {
                        gebrek.fotos.append(jpeg)
                    }
                }
                keuze = []
            }
        }
    }
}
