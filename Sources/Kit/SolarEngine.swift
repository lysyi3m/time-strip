import Foundation

/// Classifies an absolute instant + coordinate as day / twilight / night from the sun's
/// elevation angle, using the standard low-precision NOAA/Meeus solar-position algorithm
/// (accuracy ≈±1 min — far more than the shading needs).
///
/// Elevation depends only on absolute time + coordinate, so `instant` is used directly;
/// the time zone is already baked into the instant and is irrelevant to the sun's position.
/// Classifying by elevation (rather than computing sunrise/sunset and comparing) avoids
/// polar-edge branching: at the poles the elevation simply stays above or below the
/// thresholds all day.
public struct SolarClassifier: Sendable {

    /// Sun's disk at/above the horizon including atmospheric refraction.
    static let dayThreshold = -0.833
    /// Civil twilight lower bound (covers both dawn and dusk).
    static let civilTwilightThreshold = -6.0

    public init() {}

    /// Sun elevation in degrees at the given instant and location.
    public func elevation(at instant: Date, coordinate: GeoCoordinate) -> Double {
        // Julian day / century from the Unix instant.
        let jd = instant.timeIntervalSince1970 / 86400.0 + 2440587.5
        let t = (jd - 2451545.0) / 36525.0

        // Geometric mean longitude & anomaly of the sun (degrees).
        let l0 = mod360(280.46646 + t * (36000.76983 + t * 0.0003032))
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let mRad = deg2rad(m)

        // Sun's equation of center → true, then apparent, ecliptic longitude.
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3 * mRad) * 0.000289
        let trueLong = l0 + c
        let omega = 125.04 - 1934.136 * t
        let lambda = trueLong - 0.00569 - 0.00478 * sin(deg2rad(omega))

        // Obliquity of the ecliptic (corrected) → declination.
        let eps0 = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let eps = eps0 + 0.00256 * cos(deg2rad(omega))
        let epsRad = deg2rad(eps)
        let declination = asin(sin(epsRad) * sin(deg2rad(lambda)))

        // Equation of time (minutes) — Meeus/NOAA form.
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let y = pow(tan(epsRad / 2.0), 2)
        let l0Rad = deg2rad(l0)
        let eqTimeMinutes = 4.0 * rad2deg(
            y * sin(2 * l0Rad)
            - 2 * e * sin(mRad)
            + 4 * e * y * sin(mRad) * cos(2 * l0Rad)
            - 0.5 * y * y * sin(4 * l0Rad)
            - 1.25 * e * e * sin(2 * mRad)
        )

        // True solar time (minutes) in UTC: clock minutes + EoT + longitude correction.
        let utcMinutesOfDay = instant.timeIntervalSince1970
            .truncatingRemainder(dividingBy: 86400.0) / 60.0
        var trueSolarTime = utcMinutesOfDay + eqTimeMinutes + 4.0 * coordinate.longitude
        trueSolarTime = trueSolarTime.truncatingRemainder(dividingBy: 1440.0)
        if trueSolarTime < 0 { trueSolarTime += 1440.0 }

        // Hour angle (degrees): 0 at local solar noon, negative before, positive after.
        let hourAngle = trueSolarTime / 4.0 - 180.0

        let latRad = deg2rad(coordinate.latitude)
        let haRad = deg2rad(hourAngle)
        let sinElevation = sin(latRad) * sin(declination)
            + cos(latRad) * cos(declination) * cos(haRad)
        return rad2deg(asin(min(1.0, max(-1.0, sinElevation))))
    }

    /// Day / twilight / night via the elevation thresholds.
    public func period(at instant: Date, coordinate: GeoCoordinate) -> DayPeriod {
        let el = elevation(at: instant, coordinate: coordinate)
        if el >= Self.dayThreshold { return .day }
        if el >= Self.civilTwilightThreshold { return .twilight }
        return .night
    }

    // MARK: - Angle helpers

    private func deg2rad(_ d: Double) -> Double { d * .pi / 180.0 }
    private func rad2deg(_ r: Double) -> Double { r * 180.0 / .pi }
    private func mod360(_ d: Double) -> Double {
        let r = d.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }
}
