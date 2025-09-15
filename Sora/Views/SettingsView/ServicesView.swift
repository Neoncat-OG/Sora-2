//
//  ServicesView.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import SwiftUI
import Kingfisher

struct ServicesView: View {
    @StateObject private var serviceManager = ServiceManager.shared
    
    var body: some View {
        VStack {
            if serviceManager.services.isEmpty {
                emptyStateView
            } else {
                servicesList
            }
        }
        .navigationTitle("Services")
        .refreshable {
            await serviceManager.refreshDefaultServices()
        }
        .navigationBarItems(trailing:
            HStack(spacing: 16) {
                Button(action: {
                    showAddServiceAlert()
                }) {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(5)
                }
                .accessibilityLabel(NSLocalizedString("Add Service", comment: ""))
            }
        )
    }

    func showAddServiceAlert() {
        let pasteboardString = UIPasteboard.general.string ?? ""

        if !pasteboardString.isEmpty {
            let clipboardAlert = UIAlertController(
                title: "Clipboard Detected",
                message: "We found some text in your clipboard. Would you like to use it as the service URL?",
                preferredStyle: .alert
            )
            
            clipboardAlert.addAction(UIAlertAction(title: "Use Clipboard", style: .default, handler: { _ in
                self.displayServiceView(url: pasteboardString)
            }))
            
            clipboardAlert.addAction(UIAlertAction(title: "Enter Manually", style: .default, handler: { _ in
                self.showManualUrlAlert()
            }))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(clipboardAlert, animated: true, completion: nil)
            }
            
        } else {
            showManualUrlAlert()
        }
    }

    func showManualUrlAlert() {
        let alert = UIAlertController(
            title: "Add Service",
            message: "Enter the URL of the service file",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://real.url/service.json"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let url = alert.textFields?.first?.text, !url.isEmpty {
                self.displayServiceView(url: url)
            }
        }))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }

    func displayServiceView(url: String) {
        DispatchQueue.main.async {
            let addServiceView = ServiceeAdditionSettingsView(serviceUrl: url)
                .environmentObject(self.serviceManager)
            let hostingController = UIHostingController(rootView: addServiceView)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(hostingController, animated: true, completion: nil)
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Services")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var servicesList: some View {
        List {
            ForEach(serviceManager.services, id: \.id) { service in
                ServiceRow(service: service, serviceManager: serviceManager)
            }
            .onDelete(perform: deleteServices)
        }
    }
    
    private func deleteServices(offsets: IndexSet) {
        for index in offsets {
            let service = serviceManager.services[index]
            serviceManager.removeService(service)
        }
    }
}

struct ServiceRow: View {
    let service: Services
    @ObservedObject var serviceManager: ServiceManager
    @State private var showingSettings = false
    
    private var isServiceActive: Bool {
        if let managedService = serviceManager.services.first(where: { $0.id == service.id }) {
            return managedService.isActive
        }
        return service.isActive
    }
    
    private var hasSettings: Bool {
        service.metadata.settings == true
    }
    
    var body: some View {
        HStack {
            KFImage(URL(string: service.metadata.iconUrl))
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "app.dashed")
                                .foregroundColor(.secondary)
                        )
                }
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .padding(.trailing, 10)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text(service.metadata.sourceName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("v\(service.metadata.version)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                HStack(spacing: 8) {
                    Text(service.metadata.author.name)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text(service.metadata.language)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if hasSettings {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if isServiceActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                serviceManager.setServiceState(service, isActive: !isServiceActive)
            }
        }
        .sheet(isPresented: $showingSettings) {
            ServiceSettingsView(service: service, serviceManager: serviceManager)
        }
    }
}
