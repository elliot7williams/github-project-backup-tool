import Foundation

@MainActor
final class BackupRunner: ObservableObject {
    @Published var logText = ""
    @Published var isRunning = false

    func run(
        roots: String,
        owner: String,
        stagingRoot: String,
        reportPath: String,
        upload: Bool,
        includeThirdParty: Bool,
        allowSuspicious: Bool
    ) {
        guard !isRunning else { return }
        guard let scriptURL = Bundle.main.url(forResource: "backup-github-projects-mac", withExtension: "sh") else {
            append("Could not find bundled backup script.")
            return
        }

        isRunning = true
        logText = "Starting...\n"

        Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")

            var args = [
                scriptURL.path,
                "--owner", owner,
                "--staging-root", NSString(string: stagingRoot).expandingTildeInPath,
                "--report", NSString(string: reportPath).expandingTildeInPath
            ]

            let rootList = roots
                .split { $0 == "," || $0 == ";" || $0 == "\n" }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")

            if !rootList.isEmpty {
                args.append(contentsOf: ["--roots", rootList])
            }
            if upload { args.append("--upload") }
            if includeThirdParty { args.append("--include-third-party") }
            if allowSuspicious { args.append("--allow-suspicious") }

            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in self?.append(text) }
            }

            do {
                try process.run()
                process.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                await MainActor.run {
                    self?.append(process.terminationStatus == 0 ? "\nDone." : "\nFinished with exit code \(process.terminationStatus).")
                    self?.isRunning = false
                }
            } catch {
                await MainActor.run {
                    self?.append(error.localizedDescription)
                    self?.isRunning = false
                }
            }
        }
    }

    func append(_ text: String) {
        logText += text.hasSuffix("\n") ? text : text + "\n"
    }
}
