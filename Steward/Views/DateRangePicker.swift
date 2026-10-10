import SwiftUI

public struct DateRangePicker: View {
  @Binding private var startDate: Date?
  @Binding private var endDate: Date?

  private let bounds: Range<Date>?
  private let calendar: Calendar

  @State private var displayedMonth = Date()

  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: 4),
    count: 7
  )

  public init(
    startDate: Binding<Date?>,
    endDate: Binding<Date?>,
    bounds: Range<Date>? = nil,
    calendar: Calendar = .current
  ) {
    self._startDate = startDate
    self._endDate = endDate
    self.bounds = bounds
    self.calendar = calendar
  }

  private var month: Date {
    calendar.dateInterval(
      of: .month, for: displayedMonth
    )!.start
  }

  private var daysInMonth: Range<Int> {
    calendar.range(of: .day, in: .month, for: month)!
  }

  private var leadingDays: Int {
    let weekday = calendar.component(.weekday, from: month)
    return (weekday - calendar.firstWeekday + 7) % 7
  }

  private var weekdays: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let start = calendar.firstWeekday - 1
    return Array(symbols[start...] + symbols[..<start])
  }

  private func day(_ date: Date) -> Date {
    calendar.startOfDay(for: date)
  }

  private func makeDate(_ number: Int) -> Date {
    calendar.date(
      byAdding: .day,
      value: number - 1,
      to: month
    )!
  }

  private func isSelected(_ date: Date) -> Bool {
    let value = day(date)
    return (startDate.map { day($0) == value } ?? false)
      || (endDate.map { day($0) == value } ?? false)
  }

  private func isInRange(_ date: Date) -> Bool {
    guard let startDate, let endDate else { return false }
    let value = day(date)
    return value >= day(startDate) && value <= day(endDate)
  }

  private func isAllowed(_ date: Date) -> Bool {
    guard let bounds else { return true }
    return date >= day(bounds.lowerBound)
      && date < day(bounds.upperBound)
  }

  private func select(_ date: Date) {
    if startDate == nil || endDate != nil {
      startDate = date
      endDate = nil
    } else if let startDate {
      if day(date) < day(startDate) {
        self.startDate = date
        endDate = startDate
      } else {
        endDate = date
      }
    }
  }

  public var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button {
          displayedMonth = calendar.date(
            byAdding: .month, value: -1,
            to: displayedMonth
          )!
        } label: {
          Image(systemName: "chevron.left").padding(
            EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        }
        .buttonStyle(.plain)

        Spacer()

        Text(
          month.formatted(
            .dateTime.month(.wide).year()
          )
        )
        .font(.headline)

        Spacer()

        Button {
          displayedMonth = calendar.date(
            byAdding: .month, value: 1,
            to: displayedMonth
          )!
        } label: {
          Image(systemName: "chevron.right").padding(
            EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        }
        .buttonStyle(.plain)
      }

      LazyVGrid(columns: columns, spacing: 6) {
        ForEach(weekdays.indices, id: \.self) { index in
          Text(weekdays[index])
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .id("weekday-\(index)")
        }

        ForEach(0..<leadingDays, id: \.self) { index in
          Color.clear.frame(height: 30).id("blank-\(index)")
        }

        ForEach(daysInMonth, id: \.self) { number in
          let date = makeDate(number)
          let selected = isSelected(date)
          let inRange = isInRange(date)
          let allowed = isAllowed(date)

          Button {
            select(date)
          } label: {
            Text("\(number)")
              .frame(maxWidth: .infinity)
              .frame(height: 30)
              .background {
                if selected {
                  RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor)
                } else if inRange {
                  RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.18))
                }
              }
              .foregroundStyle(
                selected ? Color.white : allowed ? Color.primary : Color.secondary.opacity(0.4)
              )
          }
          .id("day-\(number)")
          .buttonStyle(.plain)
          .disabled(!allowed)
        }
      }

      HStack {
        VStack(alignment: .leading) {
          Text("Start")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(startDate?.formatted(date: .abbreviated, time: .omitted) ?? "Choose date")
        }

        Spacer()

        VStack(alignment: .trailing) {
          Text("End")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(endDate?.formatted(date: .abbreviated, time: .omitted) ?? "Choose date")
        }
      }
      .font(.subheadline)
    }
    .padding()
    .onAppear {
      displayedMonth =
        calendar.dateInterval(
          of: .month, for: startDate ?? Date()
        )!.start
    }
  }
}
