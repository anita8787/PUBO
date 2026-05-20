import SwiftUI
import SwiftData

struct PackingListView: View {
    let tripId: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @Query private var packingItems: [SDPackingItem]
    
    @State private var newItemName: String = ""
    @FocusState private var isInputFocused: Bool
    
    init(tripId: String) {
        self.tripId = tripId
        self._packingItems = Query(filter: #Predicate<SDPackingItem> { $0.trip?.id == tripId })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("行李清單")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(PuboColors.navy)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.system(size: 24))
                }
            }
            .padding(24)
            .background(Color.white)
            
            // List
            if packingItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "bag.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("尚未新增任何行李物品")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.6))
                    Spacer()
                }
            } else {
                List {
                    ForEach(packingItems) { item in
                        HStack {
                            Button(action: {
                                item.isChecked.toggle()
                            }) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isChecked ? PuboColors.navy : .gray)
                                    .font(.system(size: 20))
                            }
                            
                            Text(item.name)
                                .strikethrough(item.isChecked, color: .gray)
                                .foregroundColor(item.isChecked ? .gray : .black)
                                .font(.system(size: 16))
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            item.isChecked.toggle()
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(PlainListStyle())
            }
            
            // Bottom Input Bar
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    TextField("新增物品...", text: $newItemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem()
                            isInputFocused = true
                        }
                    
                    Button(action: {
                        addItem()
                        isInputFocused = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : PuboColors.navy)
                            .font(.system(size: 32))
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
            }
        }
        .background(Color(hex: "F8F9FA").ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
        }
    }
    
    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let descriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripId })
        let sdTrips = try? modelContext.fetch(descriptor)
        if let sdTrip = sdTrips?.first {
            let newItem = SDPackingItem(name: trimmed)
            newItem.trip = sdTrip
            modelContext.insert(newItem)
            newItemName = ""
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(packingItems[index])
        }
    }
}
