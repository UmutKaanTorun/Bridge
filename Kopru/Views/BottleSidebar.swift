import KopruCore
import SwiftUI

struct BottleSidebar: View {
    @Environment(AppModel.self) private var model
    @State private var newBottleName = ""
    @State private var importRequest: ImportRequest?

    var body: some View {
        @Bindable var model = model
        // Boşluğa tıklamak seçimi silmesin (yoksa sayfa sessizce Kur'a döner).
        List(selection: Binding(get: { model.selection }, set: { if let item = $0 { model.selection = item } })) {
            Label {
                Text("Program kur")
            } icon: {
                InstallRowIcon()
            }
            .tag(SidebarItem.install)
            Section("Bottle'lar") {
                ForEach(model.bottles) { bottle in
                    HStack {
                        Label {
                            Text(bottle.info.name)
                        } icon: {
                            if let image = model.recipeIcon(forBottle: bottle) {
                                Image(nsImage: image).resizable().frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "shippingbox")
                            }
                        }
                        Spacer()
                        if model.isRunning(bottle) {
                            Circle().fill(.green).frame(width: 7, height: 7).help("Çalışıyor")
                        }
                    }
                    .tag(SidebarItem.bottle(bottle.id))
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                BridgeGlyph()
                    .stroke(.primary, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20)
                Text("Bridge").font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 2)
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                // Taslaktaki "+ Boş bottle": tıklayınca boş bottle; basılı tutunca içe aktarma seçeneği.
                Menu {
                    Button("Bottle İçe Aktar…") { model.isPickingImportFolder = true }
                } label: {
                    Label("Boş bottle", systemImage: "plus")
                } primaryAction: {
                    model.isAskingNewBottle = true
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
                .disabled(!model.isReady || model.isInstallRunning)
                .help("Boş bir Windows 10 bottle'ı oluşturur. Bottle içe aktarmak için basılı tut ya da Dosya menüsünü kullan.")
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .onChange(of: model.isAskingNewBottle) {
            if model.isAskingNewBottle { newBottleName = "" }
        }
        .alert("Yeni Bottle", isPresented: $model.isAskingNewBottle) {
            TextField("Ad", text: $newBottleName)
            Button("Oluştur") { model.createEmptyBottle(name: newBottleName) }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Boş bir Windows 10 ortamı oluşturulur.")
        }
        .fileImporter(isPresented: $model.isPickingImportFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result { importRequest = ImportRequest(folder: folder) }
        }
        .sheet(item: $importRequest) { request in
            ImportSheet(folder: request.folder)
        }
    }
}

/// "Program kur" satırının ⊕ simgesi: taslaktaki gibi vurgu renginde; satır mavi zeminle seçiliyken beyaz.
private struct InstallRowIcon: View {
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Image(systemName: "plus.circle")
            .foregroundStyle(prominence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
    }
}

/// Bridge'in asma köprü simgesi (24 birimlik ızgarada): yol, yolda biten iki kule, aralarında sarkan ana kablo
/// ve dışa kıvrılan yan kablolar. Uygulama simgesinin (Kopru/AppIcon.icon) sadeleştirilmiş hâli: 20 pt'de
/// askılar seçilmiyor, kulelerden yola inen yan kablolar da kuleyle üçgen kurup çizimi ağaca benzetiyordu.
private struct BridgeGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
        }
        var path = Path()
        path.move(to: point(2, 16))
        path.addLine(to: point(22, 16))
        for x in [7.0, 17.0] {
            path.move(to: point(x, 6))
            path.addLine(to: point(x, 16))
        }
        path.move(to: point(2, 10.5))
        path.addCurve(to: point(7, 7), control1: point(4, 9.5), control2: point(5.5, 8.2))
        path.addCurve(to: point(17, 7), control1: point(10.33, 17), control2: point(13.67, 17))
        path.addCurve(to: point(22, 10.5), control1: point(18.5, 8.2), control2: point(20, 9.5))
        return path
    }
}
