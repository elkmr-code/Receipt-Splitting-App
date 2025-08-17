import Foundation
import SwiftData

struct ExportDataSheetModel: Identifiable {
    let id = UUID()
}

@MainActor
struct ExportService {
    @MainActor
    static func exportCSV(from context: ModelContext, start: Date, end: Date) throws -> URL {
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { e in
                e.date >= start && e.date < end
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let expenses = try context.fetch(descriptor)
        // Fully load items relationship to avoid future backing data access issues
        for e in expenses { _ = e.items }
        var csv = "Date,Name,Category,Payment,Total,Items\n"
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for e in expenses {
            let items = e.items.map { "\($0.name) $\(String(format: "%.2f", $0.price))" }.joined(separator: " | ")
            let row = [
                df.string(from: e.date),
                escape(e.name),
                e.category.rawValue,
                e.paymentMethod.rawValue,
                String(format: "%.2f", e.totalCost),
                escape(items)
            ].joined(separator: ",")
            csv.append(row + "\n")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("expenses.csv")
        try csv.data(using: .utf8)?.write(to: url)
        return url
    }
    
    private static func escape(_ value: String) -> String {
        let v = value.replacingOccurrences(of: "\"", with: "\"\"")
        if v.contains(",") || v.contains("\n") { return "\"" + v + "\"" }
        return v
    }
}

import SwiftUI
import UIKit

struct ExportDataSheet: View {
    let model: ExportDataSheetModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var showShare = false
    @State private var exportURL: URL?
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Range (max 6 months)") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                    Text(rangeHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle("Export Data")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") { export() }.disabled(!isRangeValid)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL { ExportShareSheet(activityItems: [exportURL]) }
        }
    }
    
    private var isRangeValid: Bool {
        guard startDate <= endDate else { return false }
        let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: startDate)!
        return endDate <= sixMonths
    }
    private var rangeHint: String {
        isRangeValid ? "" : "End date must be within 6 months of start date"
    }
    
    private func export() {
        do {
            exportURL = try ExportService.exportCSV(from: modelContext, start: startDate, end: endDate)
            showShare = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ExportShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}


