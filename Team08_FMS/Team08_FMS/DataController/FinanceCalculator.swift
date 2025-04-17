import Foundation
import Combine
class FinanceCalculator: ObservableObject {
    static let shared = FinanceCalculator()
    
    private let tripController = TripDataController.shared
    private let crewController = CrewDataController.shared
    
    // MARK: - Revenue Calculations
    
    func calculateTotalRevenue() -> Double {
        let allTrips = tripController.getAllTrips()
        return allTrips.reduce(0) { total, trip in
            // For each trip, calculate revenue as fuelCost + $50
            let numericDistance = Double(trip.distance.replacingOccurrences(of: " km", with: "")
                                        .replacingOccurrences(of: " miles", with: "")) ?? 0
            let fuelCost = numericDistance * 0.8
            let tripRevenue = fuelCost + 50.0
            return total + tripRevenue
        }
    }
    
    // MARK: - Expense Calculations
    
    func calculateTotalExpenses() -> Double {
        let fuelExpenses = calculatePendingTripsFuelCost()
        let salaryExpenses = calculateTotalSalaries()
        return fuelExpenses + salaryExpenses
    }
    
    private func calculatePendingTripsFuelCost() -> Double {
        // Only calculate fuel cost for trips that are not completed
        let pendingTrips = tripController.getAllTrips().filter { 
            $0.status != .delivered
        }
        
        return pendingTrips.reduce(0) { total, trip in
            let numericDistance = Double(trip.distance.replacingOccurrences(of: " km", with: "")
                                        .replacingOccurrences(of: " miles", with: "")) ?? 0
            let fuelCost = numericDistance * 0.8  // $0.8 per mile/km for fuel
            return total + fuelCost  // Note: Not adding the $50 base fee to expenses, only to revenue
        }
    }
    
    private func calculateTotalSalaries() -> Double {
        let driverSalaries = calculateDriverSalaries()
        let maintenanceSalaries = calculateMaintenancePersonnelSalaries()
        return driverSalaries + maintenanceSalaries
    }
    
    private func calculateDriverSalaries() -> Double {
        return crewController.drivers.reduce(0.0) { total, driver in
            let salary = Double(driver.salary)
            return total + salary
        }
    }
    
    private func calculateMaintenancePersonnelSalaries() -> Double {
        return crewController.maintenancePersonnel.reduce(0.0) { total, personnel in
            let salary = Double(personnel.salary)
            return total + salary
        }
    }
    
    // MARK: - Profit Calculations
    
    func calculateNetProfit() -> Double {
        return calculateTotalRevenue() - calculateTotalExpenses()
    }
    
    // MARK: - Expense Breakdown
    
    func getExpenseBreakdown() -> [(String, Double)] {
        [
            ("Fuel Costs", calculatePendingTripsFuelCost()),
            ("Driver Salaries", calculateDriverSalaries()),
            ("Maintenance Staff Salaries", calculateMaintenancePersonnelSalaries())
        ]
    }
} 
