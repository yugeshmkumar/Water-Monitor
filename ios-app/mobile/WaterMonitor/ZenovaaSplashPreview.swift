import SwiftUI

/// Preview-only view to visualize the new Zenovaa CONNECT splash screen
/// This shows what the splash screen will look like with a placeholder logo
struct ZenovaaSplashPreview: View {
    var body: some View {
        ZStack {
            // Gradient background matching the logo
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.42, blue: 0.82), // Deep blue #3869D2
                    Color(red: 0.31, green: 0.71, blue: 0.93)  // Cyan blue #4FB6ED
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Placeholder for Zenovaa logo icon
                // Replace with Image("ZenovaaLogo") once asset is added
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.42, blue: 0.82),
                                    Color(red: 0.31, green: 0.71, blue: 0.93)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    // Simplified Z symbol placeholder
                    ZStack {
                        // Top horizontal line with circles
                        HStack(spacing: 0) {
                            Circle()
                                .fill(.white)
                                .frame(width: 16, height: 16)
                            Rectangle()
                                .fill(.white)
                                .frame(width: 40, height: 4)
                            Circle()
                                .fill(Color(red: 0.31, green: 0.71, blue: 0.93))
                                .frame(width: 16, height: 16)
                        }
                        .offset(y: -20)
                        
                        // Diagonal line (Z center)
                        Rectangle()
                            .fill(.white)
                            .frame(width: 60, height: 4)
                            .rotationEffect(.degrees(-45))
                        
                        // Bottom horizontal line with circles
                        HStack(spacing: 0) {
                            Circle()
                                .fill(Color(red: 0.31, green: 0.71, blue: 0.93))
                                .frame(width: 16, height: 16)
                            Rectangle()
                                .fill(.white)
                                .frame(width: 40, height: 4)
                            Circle()
                                .fill(.white)
                                .frame(width: 16, height: 16)
                        }
                        .offset(y: 20)
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    // Company name
                    Text("Zenovaa")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    
                    // Product name
                    Text("CONNECT")
                        .font(.system(size: 24, weight: .medium, design: .default))
                        .tracking(8)
                        .foregroundStyle(Color(red: 0.7, green: 0.9, blue: 1.0))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Zenovaa Splash Screen") {
    ZenovaaSplashPreview()
}

// MARK: - Alternative with actual Image (use after adding asset)

/// Use this version once you've added the ZenovaaLogo asset to Xcode
struct ZenovaaSplashWithAsset: View {
    var body: some View {
        ZStack {
            // Gradient background matching the logo
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.42, blue: 0.82), // Deep blue
                    Color(red: 0.31, green: 0.71, blue: 0.93)  // Cyan blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Zenovaa logo icon (from Assets.xcassets)
                Image("ZenovaaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    // Company name
                    Text("Zenovaa")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    
                    // Product name
                    Text("CONNECT")
                        .font(.system(size: 24, weight: .medium, design: .default))
                        .tracking(8)
                        .foregroundStyle(Color(red: 0.7, green: 0.9, blue: 1.0))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("With Asset (ZenovaaLogo)") {
    ZenovaaSplashWithAsset()
}

// MARK: - Animated Version (Optional Enhancement)

struct ZenovaaSplashAnimated: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.42, blue: 0.82),
                    Color(red: 0.31, green: 0.71, blue: 0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image("ZenovaaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    Text("Zenovaa")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    
                    Text("CONNECT")
                        .font(.system(size: 24, weight: .medium, design: .default))
                        .tracking(8)
                        .foregroundStyle(Color(red: 0.7, green: 0.9, blue: 1.0))
                }
            }
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1.0
                scale = 1.0
            }
        }
    }
}

#Preview("Animated Version") {
    ZenovaaSplashAnimated()
}
