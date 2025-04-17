//
//  CrewProfileView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct CrewProfileView: View {
    // The crewMember is any type that conforms to CrewMemberProtocol.
    let crewMember: any CrewMemberProtocol
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var dataManager: CrewDataController

    // Editing state variables – note that for numeric fields we work with Strings for TextField binding.
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedStatus: Status?
    @State private var editedPhone: String = ""
    @State private var editedEmail: String = ""
    @State private var editedExperience: String = ""
    @State private var editedSalary: String = ""
    @State private var editedLicense: String = ""     // For Driver
    @State private var editedSpecialty: Specialization?
    
    @State private var showingDeleteAlert = false

    // MARK: - Touched States
    @State private var nameEdited = false
    @State private var phoneEdited = false
    @State private var emailEdited = false
    @State private var experienceEdited = false
    @State private var salaryEdited = false
    @State private var licenseEdited = false
    @State private var specialtyEdited = false

    // MARK: - Save Operation State
    @State private var isSaving = false

    // MARK: - Field Validations

    private var isNameValid: Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Only letters and spaces allowed.
        let regex = "^[A-Za-z ]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }

    private var isPhoneValid: Bool {
        let trimmed = editedPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Int(trimmed) != nil else { return false }
        return true
    }

    private var isEmailValid: Bool {
        let trimmed = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Basic email regex.
        let regex = #"^\S+@\S+\.\S+$"#
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }

    private var isExperienceValid: Bool {
        if let exp = Int(editedExperience), exp >= 0 {
            return true
        }
        return false
    }

    private var isSalaryValid: Bool {
        if let sal = Double(editedSalary), sal > 0 {
            return true
        }
        return false
    }

    private var isLicenseValid: Bool {
        // For drivers, license must not be empty.
        if isDriver {
            let trimmedLicense = editedLicense.trimmingCharacters(in: .whitespacesAndNewlines)
            let regex = "^[A-Z]{2}\\s?[0-9]{2}\\s?[0-9]{4}\\s?[0-9]{7}$"
            return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmedLicense)
        }
        return true
    }

    private var isSpecialtyValid: Bool {
        // For non-drivers, a specialty must be selected.
        return isDriver ? true : (editedSpecialty != nil)
    }

    // Overall form validation.
    private var isFormValid: Bool {
        isNameValid &&
        isPhoneValid &&
        isEmailValid &&
        isExperienceValid &&
        isSalaryValid &&
        isLicenseValid &&
        isSpecialtyValid
    }
    
    var body: some View {
        Form {
            // Basic Information Section.
            Section(header: Text("Basic Information")) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $editedName)
                            .onChange(of: editedName) { _, _ in nameEdited = true }
                        if nameEdited && !isNameValid {
                            Text("Name cannot be empty and must not contain numbers.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    LabeledContent(label: "ID", value: crewMember.id.uuidString)
                    LabeledContent(label: "Role", value: role)
                    
                    Picker("Status", selection: $editedStatus) {
                        ForEach([Status.available, .offDuty], id: \.self) { status in
                            Text(AppDataController.shared.getStatusString(status: status))
                                .tag(status)
                        }
                    }
                } else {
                    LabeledContent(label:"Name", value: crewMember.name)
                    LabeledContent(label:"ID", value: crewMember.id.uuidString)
                    LabeledContent(label:"Role", value: role)
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(AppDataController.shared.getStatusString(status: crewMember.status))
                            .foregroundColor(crewMember.status.color)
                    }
                }
            }
            
            // Contact Information Section.
            Section("Contact Information") {
                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Phone", text: $editedPhone)
                            .keyboardType(.numberPad)
                            .onChange(of: editedPhone) { _, _ in phoneEdited = true }
                        if phoneEdited && !isPhoneValid {
                            Text("Phone must be numeric and cannot be empty.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
//                    VStack(alignment: .leading, spacing: 4) {
//                        TextField("Email", text: $editedEmail)
//                            .keyboardType(.emailAddress)
//                            .onChange(of: editedEmail) { _, _ in emailEdited = true }
//                        if emailEdited && !isEmailValid {
//                            Text("Enter a valid email address.")
//                                .font(.caption)
//                                .foregroundColor(.red)
//                        }
//                    }
                    LabeledContent(label:"Email", value: crewMember.email)
                } else {
                    LabeledContent(label:"Phone", value: "\(crewMember.phoneNumber)")
                    LabeledContent(label:"Email", value: crewMember.email)
                }
            }
            
            // Professional Details Section.
            Section("Professional Details") {
                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Experience (years)", text: $editedExperience)
                            .keyboardType(.numberPad)
                            .onChange(of: editedExperience) { _, _ in experienceEdited = true }
                        if experienceEdited && !isExperienceValid {
                            Text("Experience must be a nonnegative number.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if isDriver {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("License Number", text: $editedLicense)
                                .onChange(of: editedLicense) { _, _ in licenseEdited = true }
                            if licenseEdited && !isLicenseValid {
                                Text("License number format is invalid. Please use the format: AA 00 0000 0000000")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("Specialty", selection: $editedSpecialty) {
                                ForEach(Specialization.allCases) { specialty in
                                    Text(AppDataController.shared.getSpecialityString(speciality: specialty))
                                        .tag(specialty as Specialization?)
                                }
                            }
                            .onChange(of: editedSpecialty) { _, _ in specialtyEdited = true }
                            if specialtyEdited && !isSpecialtyValid {
                                Text("Please select a specialty.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Monthly Salary", text: $editedSalary)
                            .keyboardType(.decimalPad)
                            .onChange(of: editedSalary) { _, _ in salaryEdited = true }
                        if salaryEdited && !isSalaryValid {
                            Text("Salary must be a positive number.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    if isDriver, let driver = crewMember as? Driver {
                        LabeledContent(label:"Experience", value: "\(driver.yearsOfExperience) years")
                        LabeledContent(label:"License", value: driver.driverLicenseNumber)
                    } else if let maintenance = crewMember as? MaintenancePersonnel {
                        LabeledContent(label:"Experience", value: "\(maintenance.yearsOfExperience) years")
                        LabeledContent(label:"Specialty", value: maintenance.speciality.rawValue)
                    }
                    LabeledContent(label:"Salary", value: "$\(String(format: "%.2f", crewMember.salary))")
                }
            }
            
            // Delete Section.
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete \(role)")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(crewMember.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
                .disabled(isEditing && (!isFormValid || isSaving))
            }
        }
        .onAppear {
            initializeEditingFields()
        }
        .alert("Delete \(role)", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCrew()
            }
        } message: {
            Text("Are you sure you want to delete this crew member? This action cannot be undone.")
        }
    }
    
    // Helper computed properties.
    var isDriver: Bool {
        crewMember is Driver
    }
    
    var role: String {
        isDriver ? "Driver" : "Maintenance"
    }
    
    // Initialize the editing fields with the crew member's current values.
    private func initializeEditingFields() {
        editedName = crewMember.name
        editedPhone = "\(crewMember.phoneNumber)"
        editedStatus = crewMember.status
        editedEmail = crewMember.email
        if isDriver, let driver = crewMember as? Driver {
            editedExperience = "\(driver.yearsOfExperience)"
            editedLicense = driver.driverLicenseNumber
            editedSalary = String(format: "%.2f", driver.salary)
        } else if let maintenance = crewMember as? MaintenancePersonnel {
            editedExperience = "\(maintenance.yearsOfExperience)"
            editedSpecialty = maintenance.speciality
            editedSalary = String(format: "%.2f", maintenance.salary)
        }
    }
    
    // Save changes back to the data controller.
    private func saveChanges() {
        guard !isSaving else { return }
        isSaving = true
        if isDriver, let driver = crewMember as? Driver,
           let index = dataManager.drivers.firstIndex(where: { $0.id == driver.id }) {
            dataManager.drivers[index].name = editedName
            dataManager.drivers[index].profileImage = String(editedName.prefix(2).uppercased())
            dataManager.drivers[index].phoneNumber = Int(editedPhone) ?? dataManager.drivers[index].phoneNumber
            dataManager.drivers[index].email = editedEmail
            dataManager.drivers[index].yearsOfExperience = Int(editedExperience) ?? dataManager.drivers[index].yearsOfExperience
            dataManager.drivers[index].driverLicenseNumber = editedLicense
            dataManager.drivers[index].status = editedStatus ?? dataManager.drivers[index].status
            dataManager.drivers[index].salary = Double(editedSalary) ?? dataManager.drivers[index].salary
            dataManager.drivers[index].updatedAt = Date()
            Task {
                defer { isSaving = false }
                await SupabaseDataController.shared.updateDriver(driver: dataManager.drivers[index])
            }
        }
        else if let maintenance = crewMember as? MaintenancePersonnel,
                  let index = dataManager.maintenancePersonnel.firstIndex(where: { $0.id == maintenance.id }) {
            dataManager.maintenancePersonnel[index].name = editedName
            dataManager.maintenancePersonnel[index].profileImage = String(editedName.prefix(2).uppercased())
            dataManager.maintenancePersonnel[index].phoneNumber = Int(editedPhone) ?? dataManager.maintenancePersonnel[index].phoneNumber
            dataManager.maintenancePersonnel[index].email = editedEmail
            dataManager.maintenancePersonnel[index].yearsOfExperience = Int(editedExperience) ?? dataManager.maintenancePersonnel[index].yearsOfExperience
            dataManager.maintenancePersonnel[index].speciality = editedSpecialty ?? dataManager.maintenancePersonnel[index].speciality
            dataManager.maintenancePersonnel[index].status = editedStatus ?? dataManager.maintenancePersonnel[index].status
            dataManager.maintenancePersonnel[index].salary = Double(editedSalary) ?? dataManager.maintenancePersonnel[index].salary
            dataManager.maintenancePersonnel[index].updatedAt = Date()
            Task {
                defer { isSaving = false }
                await SupabaseDataController.shared.updateMaintenancePersonnel(personnel: dataManager.maintenancePersonnel[index])
            }
        }
    }
    
    // Delete the crew member using the appropriate data controller method.
    private func deleteCrew() {
        if isDriver, let driver = crewMember as? Driver {
            Task {
                await SupabaseDataController.shared.softDeleteDriver(for: driver.id)
                CrewDataController.shared.update()
            }
        } else if let maintenance = crewMember as? MaintenancePersonnel {
            Task {
                await SupabaseDataController.shared.softDeleteMaintenancePersonnel(for: maintenance.id)
                CrewDataController.shared.update()
            }
        }
        CrewDataController.shared.update()
        presentationMode.wrappedValue.dismiss()
    }
}

struct AssignTaskView: View {
    let crewMember: any CrewMemberProtocol
    @Environment(\.presentationMode) var presentationMode
    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @State private var dueDate = Date()
    
    var body: some View {
        Form {
            Section(header: Text("Task Details")) {
                TextField("Task Title", text: $taskTitle)
                TextField("Description", text: $taskDescription)
                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }
        }
        .navigationTitle("Assign Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Assign") {
                    // Handle task assignment here
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(taskTitle.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationView {
        // Example preview using a Driver. You can substitute with a MaintenancePersonnel instance as needed.
        CrewProfileView(crewMember: Driver(
            userID: UUID(),
            name: "Charlie Davis",
            profileImage: "DR",
            email: "charlie.davis@example.com",
            phoneNumber: 555_111_2222,
            driverLicenseNumber: "DL123456",
            driverLicenseExpiry: Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date(),
            assignedVehicleID: nil,
            address: "123 Main Street",
            salary: 5000.0,
            yearsOfExperience: 5,
            createdAt: Date(),
            updatedAt: Date(),
            isDeleted: false,
            status: .available
        ))
    }
}
