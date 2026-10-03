//
//  Subject.swift
//  VoiceFilter_iOS
//
//  Danh sách 12 Chủ đề thử thách phát âm chuẩn theo bản Android
//

import SwiftUI

public enum Subject: String, CaseIterable, Identifiable, Codable {
    case colors = "colors"
    case carBrands = "car_brands"
    case weekdays = "weekdays"
    case months = "months"
    case animals = "animals"
    case vehicles = "vehicles"
    case kitchen = "kitchen"
    case countries = "countries"
    case dailyWords = "daily_words"
    case travelFood = "travel_food"
    case entertainmentSports = "entertainment_sports"
    case slangBrainrot = "slang_brainrot"

    public var id: String { rawValue }

    public var key: String { rawValue }

    public var titleEn: String {
        switch self {
        case .colors: return "Colors"
        case .carBrands: return "Car Brands"
        case .weekdays: return "Weekdays"
        case .months: return "Months"
        case .animals: return "Animals"
        case .vehicles: return "Vehicles"
        case .kitchen: return "Kitchen Utensils"
        case .countries: return "Countries"
        case .dailyWords: return "Daily Words"
        case .travelFood: return "Travel & Food"
        case .entertainmentSports: return "Movies & Sports"
        case .slangBrainrot: return "Slang & Pop Culture"
        }
    }

    public var titleVi: String {
        switch self {
        case .colors: return "Màu sắc"
        case .carBrands: return "Hãng xe"
        case .weekdays: return "Ngày trong tuần"
        case .months: return "Tháng trong năm"
        case .animals: return "Động vật"
        case .vehicles: return "Phương tiện"
        case .kitchen: return "Dụng cụ bếp"
        case .countries: return "Quốc gia"
        case .dailyWords: return "Từ vựng hàng ngày"
        case .travelFood: return "Du lịch & Ẩm thực"
        case .entertainmentSports: return "Phim ảnh & Thể thao"
        case .slangBrainrot: return "Từ lóng & Giới trẻ"
        }
    }

    public var emoji: String {
        switch self {
        case .colors: return "🎨"
        case .carBrands: return "🚗"
        case .weekdays: return "📅"
        case .months: return "🗓️"
        case .animals: return "🦁"
        case .vehicles: return "🚀"
        case .kitchen: return "🍳"
        case .countries: return "🌍"
        case .dailyWords: return "☕"
        case .travelFood: return "✈️"
        case .entertainmentSports: return "🎬"
        case .slangBrainrot: return "🔥"
        }
    }

    public var learnersCount: Int {
        switch self {
        case .colors: return 19740
        case .carBrands: return 15516
        case .weekdays: return 24110
        case .months: return 18230
        case .animals: return 33224
        case .vehicles: return 21890
        case .kitchen: return 12450
        case .countries: return 32261
        case .dailyWords: return 41200
        case .travelFood: return 38900
        case .entertainmentSports: return 29500
        case .slangBrainrot: return 52300
        }
    }

    public var cardColor: Color {
        switch self {
        case .colors: return Color(red: 0.18, green: 0.50, blue: 0.93)
        case .carBrands: return Color(red: 1.0, green: 0.44, blue: 0.26)
        case .weekdays: return Color(red: 0.16, green: 0.71, blue: 0.96)
        case .months: return Color(red: 0.67, green: 0.28, blue: 0.74)
        case .animals: return Color(red: 0.30, green: 0.69, blue: 0.31)
        case .vehicles: return Color(red: 0.49, green: 0.34, blue: 0.76)
        case .kitchen: return Color(red: 1.0, green: 0.65, blue: 0.15)
        case .countries: return Color(red: 0.15, green: 0.65, blue: 0.60)
        case .dailyWords: return Color(red: 0.0, green: 0.67, blue: 0.76)
        case .travelFood: return Color(red: 1.0, green: 0.44, blue: 0.26)
        case .entertainmentSports: return Color(red: 0.56, green: 0.14, blue: 0.67)
        case .slangBrainrot: return Color(red: 1.0, green: 0.09, blue: 0.27)
        }
    }

    public var accentColor: Color {
        switch self {
        case .colors: return Color(red: 0.11, green: 0.41, blue: 0.78)
        case .carBrands: return Color(red: 0.90, green: 0.29, blue: 0.10)
        case .weekdays: return Color(red: 0.01, green: 0.53, blue: 0.82)
        case .months: return Color(red: 0.48, green: 0.12, blue: 0.64)
        case .animals: return Color(red: 0.18, green: 0.49, blue: 0.20)
        case .vehicles: return Color(red: 0.32, green: 0.18, blue: 0.66)
        case .kitchen: return Color(red: 0.96, green: 0.49, blue: 0.0)
        case .countries: return Color(red: 0.0, green: 0.47, blue: 0.42)
        case .dailyWords: return Color(red: 0.0, green: 0.51, blue: 0.56)
        case .travelFood: return Color(red: 0.85, green: 0.26, blue: 0.08)
        case .entertainmentSports: return Color(red: 0.42, green: 0.11, blue: 0.60)
        case .slangBrainrot: return Color(red: 0.84, green: 0.0, blue: 0.0)
        }
    }

    public static func fromKey(_ key: String) -> Subject {
        return Subject(rawValue: key.lowercased()) ?? .colors
    }
}
