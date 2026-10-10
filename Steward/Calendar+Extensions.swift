import Foundation

extension Calendar {
  public func endOfDay(for date: Date) -> Date {
    let startOfNextDay = self.date(
      byAdding: .day,
      value: 1,
      to: self.startOfDay(for: date)
    )!
    return startOfNextDay.addingTimeInterval(-1)
  }
}
