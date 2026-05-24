//
//  AstronomyEngine.swift
//  StarPath
//
//  Pure-Swift port of the orbital mechanics from starpath/main.js.
//  Computes geocentric ecliptic longitudes for Sun, Moon, and planets
//  using classical orbital elements and perturbation corrections.
//

import Foundation

// MARK: - Math Helpers

@inline(__always)
func toRad(_ deg: Double) -> Double { deg * .pi / 180 }

@inline(__always)
func toDeg(_ rad: Double) -> Double { rad * 180 / .pi }

@inline(__always)
func sinDeg(_ deg: Double) -> Double { sin(toRad(deg)) }

@inline(__always)
func cosDeg(_ deg: Double) -> Double { cos(toRad(deg)) }

func normalizeAngle(_ angle: Double) -> Double {
    var a = angle.truncatingRemainder(dividingBy: 360)
    if a < 0 { a += 360 }
    return a
}

/// Signed angular delta in [-180, 180]
func signedDelta(_ target: Double, _ origin: Double) -> Double {
    var d = normalizeAngle(target - origin)
    if d > 180 { d -= 360 }
    return d
}

// MARK: - Kepler Solver

func solveKepler(M mRad: Double, e: Double) -> Double {
    var E = mRad + e * sin(mRad) * (1 + e * cos(mRad))
    for _ in 0..<10 {
        let dE = (E - e * sin(E) - mRad) / (1 - e * cos(E))
        E -= dE
        if abs(dE) < 1e-6 { break }
    }
    return E
}

// MARK: - Orbital Elements

struct OrbitalElements {
    let N: Double // longitude of ascending node
    let i: Double // inclination
    let w: Double // argument of perihelion
    let a: Double // semi-major axis (AU)
    let e: Double // eccentricity
    let M: Double // mean anomaly
}

func orbitalElements(for planet: String, d: Double) -> OrbitalElements {
    switch planet {
    case "mercury":
        return OrbitalElements(
            N: 48.3313 + 3.24587e-5 * d,
            i: 7.0047 + 5.0e-8 * d,
            w: 29.1241 + 1.01444e-5 * d,
            a: 0.387098,
            e: 0.205635 + 5.59e-10 * d,
            M: 168.6562 + 4.0923344368 * d
        )
    case "venus":
        return OrbitalElements(
            N: 76.6799 + 2.4659e-5 * d,
            i: 3.3946 + 2.75e-8 * d,
            w: 54.891 + 1.38374e-5 * d,
            a: 0.72333,
            e: 0.006773 - 1.302e-9 * d,
            M: 48.0052 + 1.6021302244 * d
        )
    case "earth":
        return OrbitalElements(
            N: 0,
            i: 0,
            w: 282.9404 + 4.70935e-5 * d,
            a: 1,
            e: 0.016709 - 1.151e-9 * d,
            M: 356.047 + 0.9856002585 * d
        )
    case "mars":
        return OrbitalElements(
            N: 49.5574 + 2.11081e-5 * d,
            i: 1.8497 - 1.78e-8 * d,
            w: 286.5016 + 2.92961e-5 * d,
            a: 1.523688,
            e: 0.093405 + 2.516e-9 * d,
            M: 18.6021 + 0.5240207766 * d
        )
    case "jupiter":
        return OrbitalElements(
            N: 100.4542 + 2.76854e-5 * d,
            i: 1.303 - 1.557e-7 * d,
            w: 273.8777 + 1.64505e-5 * d,
            a: 5.20256,
            e: 0.048498 + 4.469e-9 * d,
            M: 19.895 + 0.0830853001 * d
        )
    case "saturn":
        return OrbitalElements(
            N: 113.6634 + 2.3898e-5 * d,
            i: 2.4886 - 1.081e-7 * d,
            w: 339.3939 + 2.97661e-5 * d,
            a: 9.55475,
            e: 0.055546 - 9.499e-9 * d,
            M: 316.967 + 0.0334442282 * d
        )
    case "uranus":
        return OrbitalElements(
            N: 74.0005 + 1.3978e-5 * d,
            i: 0.7733 + 1.9e-8 * d,
            w: 96.6612 + 3.0565e-5 * d,
            a: 19.18171 - 1.55e-8 * d,
            e: 0.047318 + 7.45e-9 * d,
            M: 142.5905 + 0.011725806 * d
        )
    case "neptune":
        return OrbitalElements(
            N: 131.7806 + 3.0173e-5 * d,
            i: 1.77 - 2.55e-7 * d,
            w: 272.8461 - 6.027e-6 * d,
            a: 30.05826 + 3.313e-8 * d,
            e: 0.008606 + 2.15e-9 * d,
            M: 260.2471 + 0.005995147 * d
        )
    default:
        fatalError("Unknown planet: \(planet)")
    }
}

// MARK: - Coordinate Transforms

struct RectCoord {
    let x: Double
    let y: Double
    let z: Double
}

struct SphericalCoord {
    let lon: Double
    let lat: Double
    let r: Double
}

func rectangularFromElements(_ el: OrbitalElements) -> RectCoord {
    let mRad = toRad(normalizeAngle(el.M))
    let E = solveKepler(M: mRad, e: el.e)

    let xv = el.a * (cos(E) - el.e)
    let yv = el.a * (sqrt(1 - el.e * el.e) * sin(E))

    let v = atan2(yv, xv)
    let r = sqrt(xv * xv + yv * yv)

    let nRad = toRad(el.N)
    let iRad = toRad(el.i)
    let wRad = toRad(el.w)
    let vw = v + wRad

    let xh = r * (cos(nRad) * cos(vw) - sin(nRad) * sin(vw) * cos(iRad))
    let yh = r * (sin(nRad) * cos(vw) + cos(nRad) * sin(vw) * cos(iRad))
    let zh = r * sin(vw) * sin(iRad)

    return RectCoord(x: xh, y: yh, z: zh)
}

func sphericalFromRectangular(_ r: RectCoord) -> SphericalCoord {
    let lon = normalizeAngle(toDeg(atan2(r.y, r.x)))
    let lat = toDeg(atan2(r.z, sqrt(r.x * r.x + r.y * r.y)))
    let dist = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
    return SphericalCoord(lon: lon, lat: lat, r: dist)
}

// MARK: - Heliocentric State

struct HelioState {
    let rect: RectCoord
    let sph: SphericalCoord
    let M: Double
}

func heliocentricState(planet: String, d: Double) -> HelioState {
    let el = orbitalElements(for: planet, d: d)
    let rect = rectangularFromElements(el)
    let sph = sphericalFromRectangular(rect)
    return HelioState(rect: rect, sph: sph, M: normalizeAngle(el.M))
}

// MARK: - Julian Day / Days Since J2000

func julianDay(_ date: Date) -> Double {
    date.timeIntervalSince1970 / 86400 + 2440587.5
}

func daysSinceJ2000(_ date: Date) -> Double {
    julianDay(date) - 2451543.5
}

// MARK: - Sun Position

func sunGeocentricLongitude(d: Double) -> (lon: Double, meanAnomaly: Double, trueLon: Double) {
    let el = orbitalElements(for: "earth", d: d)
    let M = normalizeAngle(el.M)
    let mRad = toRad(M)

    // Equation of center
    let C = (1.9146 - 0.004817 * d / 36525 - 0.000014 * pow(d / 36525, 2)) * sin(mRad)
        + 0.019993 * sin(2 * mRad)
        + 0.00029 * sin(3 * mRad)

    let sunTrueLon = normalizeAngle(el.w + M + C)
    return (lon: sunTrueLon, meanAnomaly: M, trueLon: sunTrueLon)
}

// MARK: - Moon Geocentric Longitude

func moonGeocentricLongitude(d: Double, sunMeanAnomaly: Double, sunTrueLongitude: Double) -> Double {
    let N = 125.1228 - 0.0529538083 * d
    let i = 5.1454
    let w = 318.0634 + 0.1643573223 * d
    let a = 60.2666
    let e = 0.0549
    let M = 115.3654 + 13.0649929509 * d

    let E = solveKepler(M: toRad(normalizeAngle(M)), e: e)
    let xv = a * (cos(E) - e)
    let yv = a * (sqrt(1 - e * e) * sin(E))
    let v = atan2(yv, xv)
    let r = sqrt(xv * xv + yv * yv)

    let nRad = toRad(N)
    let iRad = toRad(i)
    let wRad = toRad(w)
    let vw = v + wRad
    let xh = r * (cos(nRad) * cos(vw) - sin(nRad) * sin(vw) * cos(iRad))
    let yh = r * (sin(nRad) * cos(vw) + cos(nRad) * sin(vw) * cos(iRad))

    var lon = normalizeAngle(toDeg(atan2(yh, xh)))
    var lat = toDeg(atan2(r * sin(vw) * sin(iRad), sqrt(xh * xh + yh * yh)))

    let Mm = normalizeAngle(M)
    let Ms = normalizeAngle(sunMeanAnomaly)
    let Lm = normalizeAngle(N + w + M)
    let Ls = normalizeAngle(sunTrueLongitude)
    let D = normalizeAngle(Lm - Ls)
    let F = normalizeAngle(Lm - N)

    lon += -1.274 * sinDeg(Mm - 2 * D)
        + 0.658 * sinDeg(2 * D)
        - 0.186 * sinDeg(Ms)
        - 0.059 * sinDeg(2 * Mm - 2 * D)
        - 0.057 * sinDeg(Mm - 2 * D + Ms)
        + 0.053 * sinDeg(Mm + 2 * D)
        + 0.046 * sinDeg(2 * D - Ms)
        + 0.041 * sinDeg(Mm - Ms)
        - 0.035 * sinDeg(D)
        - 0.031 * sinDeg(Mm + Ms)
        - 0.015 * sinDeg(2 * F - 2 * D)
        + 0.011 * sinDeg(Mm - 4 * D)

    lat += -0.173 * sinDeg(F - 2 * D)
        - 0.055 * sinDeg(Mm - F - 2 * D)
        - 0.046 * sinDeg(Mm + F - 2 * D)
        + 0.033 * sinDeg(F + 2 * D)
        + 0.017 * sinDeg(2 * Mm + F)

    return normalizeAngle(lon)
}

// MARK: - Planet Geocentric Longitude

func planetGeocentricLongitude(planet: String, d: Double) -> Double {
    // Get heliocentric positions of Earth and target planet
    let earthRect = rectangularFromElements(orbitalElements(for: "earth", d: d))

    let planetState = heliocentricState(planet: planet, d: d)

    // earthRect is the Sun's geocentric position (S − E), not Earth's heliocentric.
    // planet_geo = planet_helio + sun_geo = (P−S) + (S−E) = P − E
    let geoX = planetState.rect.x + earthRect.x
    let geoY = planetState.rect.y + earthRect.y
    let geoZ = planetState.rect.z + earthRect.z

    let geoSph = sphericalFromRectangular(RectCoord(x: geoX, y: geoY, z: geoZ))
    return geoSph.lon
}

// MARK: - Geocentric Distance (AU)

/// Compute geocentric distance for a planet (in AU).
func planetGeocentricDistance(planet: String, d: Double) -> Double {
    let earthRect = rectangularFromElements(orbitalElements(for: "earth", d: d))
    let planetState = heliocentricState(planet: planet, d: d)

    let geoX = planetState.rect.x + earthRect.x
    let geoY = planetState.rect.y + earthRect.y
    let geoZ = planetState.rect.z + earthRect.z

    return sqrt(geoX * geoX + geoY * geoY + geoZ * geoZ)
}

/// Compute geocentric distance to the Sun (in AU).
func sunGeocentricDistance(d: Double) -> Double {
    let earthRect = rectangularFromElements(orbitalElements(for: "earth", d: d))
    return sqrt(earthRect.x * earthRect.x + earthRect.y * earthRect.y + earthRect.z * earthRect.z)
}

/// Moon geocentric distance in AU (convert from Earth-radii).
func moonGeocentricDistance(d: Double) -> Double {
    let a = 60.2666 // Earth radii
    let e = 0.0549
    let M = 115.3654 + 13.0649929509 * d

    let E = solveKepler(M: toRad(normalizeAngle(M)), e: e)
    let xv = a * (cos(E) - e)
    let yv = a * (sqrt(1 - e * e) * sin(E))
    let r = sqrt(xv * xv + yv * yv) // in Earth radii

    // Convert Earth radii to AU: 1 Earth radius ≈ 6378.137 km, 1 AU ≈ 149597870.7 km
    let earthRadiusAU = 6378.137 / 149597870.7
    return r * earthRadiusAU
}

// MARK: - Depth Context

struct DepthContext {
    let distances: [String: Double] // body id -> geocentric distance in AU

    func distance(for bodyId: String) -> Double {
        distances[bodyId] ?? 1
    }
}

func geocentricDepthContext(for date: Date) -> DepthContext {
    let d = daysSinceJ2000(date)
    var distances: [String: Double] = [:]

    distances["sun"] = sunGeocentricDistance(d: d)
    distances["moon"] = moonGeocentricDistance(d: d)

    for planet in ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"] {
        distances[planet] = planetGeocentricDistance(planet: planet, d: d)
    }

    return DepthContext(distances: distances)
}

// MARK: - Complete Geocentric State

struct GeocentricState {
    let sun: Double
    let moon: Double
    let mercury: Double
    let venus: Double
    let mars: Double
    let jupiter: Double
    let saturn: Double
    let uranus: Double
    let neptune: Double

    func longitude(for bodyId: String) -> Double {
        switch bodyId {
        case "sun": return sun
        case "moon": return moon
        case "mercury": return mercury
        case "venus": return venus
        case "mars": return mars
        case "jupiter": return jupiter
        case "saturn": return saturn
        case "uranus": return uranus
        case "neptune": return neptune
        default: return 0
        }
    }
}

// MARK: - Complete Heliocentric State

struct HeliocentricState {
    let earth: Double
    let mercury: Double
    let venus: Double
    let mars: Double
    let jupiter: Double
    let saturn: Double
    let uranus: Double
    let neptune: Double

    func longitude(for bodyId: String) -> Double {
        switch bodyId {
        case "earth": return earth
        case "mercury": return mercury
        case "venus": return venus
        case "mars": return mars
        case "jupiter": return jupiter
        case "saturn": return saturn
        case "uranus": return uranus
        case "neptune": return neptune
        default: return 0
        }
    }
}

func heliocentricLongitudes(for date: Date) -> HeliocentricState {
    let d = daysSinceJ2000(date)

    // Earth's heliocentric longitude is opposite to the Sun's geocentric longitude
    let sunLon = sunGeocentricLongitude(d: d).lon
    let earthLon = normalizeAngle(sunLon + 180)

    let planets = ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
    var lons: [String: Double] = [:]
    for p in planets {
        lons[p] = heliocentricState(planet: p, d: d).sph.lon
    }

    return HeliocentricState(
        earth: earthLon,
        mercury: lons["mercury"]!,
        venus: lons["venus"]!,
        mars: lons["mars"]!,
        jupiter: lons["jupiter"]!,
        saturn: lons["saturn"]!,
        uranus: lons["uranus"]!,
        neptune: lons["neptune"]!
    )
}

// MARK: - Moon Phase

/// Returns the moon phase as a fraction: 0 = new moon, 0.5 = full moon, 1 = next new moon.
/// Also returns the elongation (Sun–Moon angle) for determining waxing vs waning.
func moonPhase(for date: Date) -> (phase: Double, isWaxing: Bool) {
    let d = daysSinceJ2000(date)
    let sunResult = sunGeocentricLongitude(d: d)
    let moonLon = moonGeocentricLongitude(
        d: d,
        sunMeanAnomaly: sunResult.meanAnomaly,
        sunTrueLongitude: sunResult.trueLon
    )
    // Elongation: Moon longitude - Sun longitude
    let elongation = normalizeAngle(moonLon - sunResult.lon) // 0..360
    let phase = elongation / 360.0 // 0 = new, 0.5 = full
    let isWaxing = elongation < 180
    return (phase: phase, isWaxing: isWaxing)
}

/// Returns the appropriate SF Symbol name for the current moon phase.
func moonPhaseSymbol(for date: Date) -> String {
    let (phase, _) = moonPhase(for: date)
    // Map phase (0..1) to 8 standard moon phase icons
    switch phase {
    case 0..<0.0625:    return "moonphase.new.moon"
    case 0.0625..<0.1875: return "moonphase.waxing.crescent"
    case 0.1875..<0.3125: return "moonphase.first.quarter"
    case 0.3125..<0.4375: return "moonphase.waxing.gibbous"
    case 0.4375..<0.5625: return "moonphase.full.moon"
    case 0.5625..<0.6875: return "moonphase.waning.gibbous"
    case 0.6875..<0.8125: return "moonphase.last.quarter"
    case 0.8125..<0.9375: return "moonphase.waning.crescent"
    default:             return "moonphase.new.moon"
    }
}

func geocentricLongitudes(for date: Date) -> GeocentricState {
    let d = daysSinceJ2000(date)
    let sunResult = sunGeocentricLongitude(d: d)
    let sunLon = sunResult.lon

    let moonLon = moonGeocentricLongitude(
        d: d,
        sunMeanAnomaly: sunResult.meanAnomaly,
        sunTrueLongitude: sunResult.trueLon
    )

    let planets = ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
    var lons: [String: Double] = [:]
    for p in planets {
        lons[p] = planetGeocentricLongitude(planet: p, d: d)
    }

    return GeocentricState(
        sun: sunLon,
        moon: moonLon,
        mercury: lons["mercury"]!,
        venus: lons["venus"]!,
        mars: lons["mars"]!,
        jupiter: lons["jupiter"]!,
        saturn: lons["saturn"]!,
        uranus: lons["uranus"]!,
        neptune: lons["neptune"]!
    )
}
