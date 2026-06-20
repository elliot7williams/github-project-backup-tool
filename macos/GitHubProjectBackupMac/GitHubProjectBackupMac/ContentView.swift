import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var runner = BackupRunner()

    @State private var roots = "/Volumes/ProjectDrive,/Volumes/BackupDrive"
    @State private var owner = "YOUR_GITHUB_USERNAME"
    @State private var stagingRoot = "~/GitHubProjectBackupStaging"
    @State private var reportPath = "~/Desktop/github-project-backup-report.csv"
    @State private var upload = false
    @State private var includeThirdParty = false
    @State private var allowSuspicious = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            form
            logView
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 3) {
                Text("GitHub Project Backup")
                    .font(.system(size: 26, weight: .semibold))
                Text("Scan external drives, stage clean source copies, and upload private GitHub repositories.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var form: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Roots")
                TextField("/Volumes/DriveA,/Volumes/DriveB", text: $roots)
                Button("Choose") { chooseFolders() }
            }
            GridRow {
                Text("Owner")
                TextField("GitHub username or org", text: $owner)
                EmptyView()
            }
            GridRow {
                Text("Staging")
                TextField("~/GitHubProjectBackupStaging", text: $stagingRoot)
                Button("Choose") { chooseFolder(into: $stagingRoot) }
            }
            GridRow {
                Text("Report")
                TextField("~/Desktop/github-project-backup-report.csv", text: $reportPath)
                Button("Save As") { chooseReport() }
            }
            GridRow {
                Text("Options")
                HStack(spacing: 18) {
                    Toggle("Upload private repos", isOn: $upload)
                    Toggle("Include third-party", isOn: $includeThirdParty)
                    Toggle("Allow suspicious files", isOn: $allowSuspicious)
                }
                .toggleStyle(.checkbox)
                EmptyView()
            }
            GridRow {
                Text("")
                HStack {
                    Button(runner.isRunning ? "Running..." : "Run") {
                        runner.run(
                            roots: roots,
                            owner: owner,
                            stagingRoot: stagingRoot,
                            reportPath: reportPath,
                            upload: upload,
                            includeThirdParty: includeThirdParty,
                            allowSuspicious: allowSuspicious
                        )
                    }
                    .disabled(runner.isRunning)
                    .keyboardShortcut(.return, modifiers: [.command])

                    Button("Open Report") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: expanded(reportPath)))
                    }
                    Spacer()
                }
                EmptyView()
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var logView: some View {
        ScrollView {
            Text(runner.logText.isEmpty ? "Run a scan to see logs here." : runner.logText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color(nsColor: .textColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(minHeight: 300)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
    }

    private func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            roots = panel.urls.map(\.path).joined(separator: ",")
        }
    }

    private func chooseFolder(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path
        }
    }

    private func chooseReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "github-project-backup-report.csv"
        if panel.runModal() == .OK, let url = panel.url {
            reportPath = url.path
        }
    }

    private func expanded(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}

#Preview {
    ContentView()
}
