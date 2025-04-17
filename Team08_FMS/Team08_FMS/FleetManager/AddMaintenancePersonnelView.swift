//  AddMaintenancePersonnelView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct AddMaintenancePersonnelView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var supabase = SupabaseDataController.shared
    @StateObject private var crewDataController = CrewDataController.shared

    // Maintenance personnel information
    @State private var name = ""
    @State private var avatar = ""
    @State private var experience = ""
    @State private var specialty: Specialization = .engineRepair
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var certification: Certification = .aseCertified
    @State private var salary = ""
    @State private var address = ""

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !experience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !salary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Basic Information") {
                    TextField("Full Name", text: $name)
                    TextField("Avatar Initials", text: $avatar)
                        .onChange(of: name) {
                            if avatar.isEmpty {
                                let words = name.components(separatedBy: " ")
                                avatar = words.compactMap { $0.first }.map(String.init).joined()
                            }
                        }
                }
                
                // Contact Information
                Section("Contact Information") {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                // Professional Details
                Section("Professional Details") {
                    TextField("Experience (years)", text: $experience)
                        .keyboardType(.numberPad)
                    
                    Picker("Specialty", selection: $specialty) {
                        ForEach(Specialization.allCases, id: \.self) { specialty in
                            Text(specialty.rawValue)
                        }
                    }
                    
                    Picker("Certification", selection: $certification) {
                        ForEach(Certification.allCases, id: \.self) { certification in
                            Text(certification.rawValue)
                        }
                    }
                    
                    TextField("Salary", text: $salary)
                        .keyboardType(.decimalPad)
                    TextField("Address", text: $address)
                }
            }
            .navigationTitle("Add Maintenance Personnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMaintenancePersonnel()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveMaintenancePersonnel() {
        var newPersonnel = MaintenancePersonnel(
            userID: UUID(),
            name: name,
            profileImage: avatar.isEmpty ? String(name.prefix(2).uppercased()) : avatar,
            email: email,
            phoneNumber: Int(phoneNumber) ?? 0,
            certifications: certification,
            yearsOfExperience: Int(experience) ?? 0,
            speciality: specialty,
            salary: Double(salary) ?? 5000.0,
            address: address.isEmpty ? nil : address,
            createdAt: Date(),
            status: .available
        )
        
        Task {
            do {
                guard let signUpID = await supabase.signUp(name: newPersonnel.name, email: newPersonnel.email, phoneNo: newPersonnel.phoneNumber, role: "maintenance_personnel") else { return }
                newPersonnel.userID = signUpID
                try await supabase.insertMaintenancePersonnel(personnel: newPersonnel, password: AppDataController.shared.randomPasswordGenerator(length: 6))
                await supabase.setUserSession()
                await MainActor.run {
                    crewDataController.update()
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Error inserting maintenance personnel: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    AddMaintenancePersonnelView()
        .environmentObject(SupabaseDataController.shared)
}
