plugins { id("com.android.library"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "org.godotengine.plugin.android.LiveWallpaper"
    compileSdk = 35
    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = "LiveWallpaper"
        manifestPlaceholders["godotPluginPackageName"] = "org.godotengine.plugin.android.LiveWallpaper"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies { compileOnly("org.godotengine:godot:4.7.2.stable") }
