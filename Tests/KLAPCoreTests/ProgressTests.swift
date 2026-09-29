import KLAPCore
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
expect(StudyProgress(percent: -2, current: -1, total: -1) == StudyProgress(percent: 0, current: 0, total: 0), "Negative values")
expect(StudyProgress(percent: 150, current: 9, total: 3).fraction == 1, "Upper bound")
expect(StudyProgress(percent: .nan, current: 1, total: 3).fraction == 0, "NaN")
expect(StudyProgress(percent: .infinity, current: 1, total: 3).fraction == 0, "Infinity")
expect(StudyProgress(percent: 35, current: 2, total: 5).label == "2/5", "Queue position")
expect(StudyProgress(percent: 0, current: 1, total: 0).label == "", "Empty queue")
expect(StudyProgress(percent: 0, current: 8, total: 5).label == "5/5", "Queue clamp")
print("7 progress checks passed")
